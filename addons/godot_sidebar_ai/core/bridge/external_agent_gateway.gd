@tool
extends RefCounted
class_name AISidebarExternalAgentGateway

## MCP-facing adapter for Godot AI Sidebar capabilities and external-agent policy.
## MCP transport and JSON-RPC code call only this boundary for tool discovery/execution.

const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarSceneTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/scene_tools.gd")
const AISidebarWriterLock = preload("res://addons/godot_sidebar_ai/core/security/writer_lock.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

const DEFAULT_PORT := 6570
const SYNC_TIMEOUT_MSEC := 30000
const EXPECTED_SCENE_ARG := "expected_scene_path"

## Read-only observation and runtime capabilities. File writing/deletion stays with the external agent.
const EXPOSED_TOOLS: Array[String] = [
	"get_project_files", "search_project_assets", "analyze_project",
	"get_scene_tree", "get_node_properties", "get_selected_nodes", "select_node", "open_scene",
	"read_script", "validate_script",
	"play_game", "stop_game", "restart_game", "send_input",
	"get_runtime_errors", "inspect_runtime_tree", "inspect_runtime_node",
	"take_editor_screenshot", "take_viewport_screenshot", "take_runtime_screenshot",
	"inspect_ui_layout",
]

## Undoable scene mutations are the only externally exposed write capabilities.
const MUTATION_TOOLS: Array[String] = [
	"add_node", "set_node_property", "instantiate_scene", "attach_script_to_node", "save_scene",
]

const SYNC_PROJECT_TOOL := {
	"name": "sync_project",
	"description": "Call after you create or change project files with your own file tools (GDScript, .tscn, .tres, .gdshader, data files) and before validate_script, play_game or any scene tool. Rescans the Godot editor's file system and waits until the scan ends. List every changed file in changed_files, especially every .tscn: if one is the scene open in the editor, it is reloaded from disk so a later save_scene does not overwrite your file with the editor's stale copy. The result reports the submitted paths and open scenes reloaded; it does not claim per-file import success.",
	"inputSchema": {"type": "object", "properties": {
		"changed_files": {"type": "array", "items": {"type": "string"}, "description": "res:// paths you created or changed (at least every .tscn)."},
	}},
}

const INSTRUCTIONS := "Godot editor tools from the Godot AI Sidebar plugin. If the project has an AGENTS.md at its root, read it first: it holds the project's rules. Construction is file-first: create scripts, scenes (.tscn), resources (.tres), shaders and data files with your own file tools, prefer whole .tscn files or procedural GDScript over many single-node calls, then call sync_project (list all changed files, especially every .tscn, in changed_files). Editor interaction is tool-first: use the scene tools (add_node, set_node_property, instantiate_scene, attach_script_to_node, save_scene) only for small, precise, undoable edits of the scene open in the editor; they need an expected_scene_path (scene_file from get_scene_tree). Read tool schemas before calling tools and use their exact argument names. validate_script checks in-memory compilation in the current editor context only; it does not prove clean-cache dependency builds or runtime behavior. Verify dependencies and execution with the project's documented headless commands, then use play_game, get_runtime_errors (wait a few seconds after play_game), take_runtime_screenshot, inspect_runtime_tree and inspect_runtime_node (includes script variables) for editor runtime evidence; use send_input to press keys, trigger input actions or click nodes in the running game; stop_game when done."

## Tests may inject a scene root provider; production uses the active editor scene.
var scene_root_provider: Callable = Callable()

func tool_definitions() -> Array:
	var out: Array = []
	for schema_value: Variant in AISidebarToolManager.get_all_schemas():
		var schema: Dictionary = schema_value
		var fn: Dictionary = schema.get("function", {})
		var name := str(fn.get("name", ""))
		if EXPOSED_TOOLS.has(name):
			out.append({
				"name": name,
				"description": str(fn.get("description", "")),
				"inputSchema": fn.get("parameters", {"type": "object", "properties": {}}),
			})
		elif MUTATION_TOOLS.has(name):
			var parameters: Dictionary = fn.get("parameters", {})
			out.append(_mutation_definition(name, str(fn.get("description", "")), parameters))
	out.append(SYNC_PROJECT_TOOL.duplicate(true))
	return out

func is_tool_exposed(tool_name: String) -> bool:
	return EXPOSED_TOOLS.has(tool_name) or MUTATION_TOOLS.has(tool_name) or tool_name == SYNC_PROJECT_TOOL["name"]

func instructions() -> String:
	return INSTRUCTIONS

func is_mutation_tool(tool_name: String) -> bool:
	return MUTATION_TOOLS.has(tool_name)

func dispatch(tool_name: String, args: Dictionary) -> Dictionary:
	if not is_tool_exposed(tool_name):
		return AISidebarToolResult.err("UNKNOWN_TOOL", "Not an exposed external-agent tool: " + tool_name, false)
	if tool_name == SYNC_PROJECT_TOOL["name"]:
		return await _sync_project(args)
	if is_mutation_tool(tool_name):
		return run_mutation(tool_name, args)
	if AISidebarToolManager.is_async_tool(tool_name):
		return await AISidebarToolManager.execute_tool_async(tool_name, args, false)
	return AISidebarToolManager.execute_tool(tool_name, args, false)

func run_mutation(tool_name: String, args: Dictionary) -> Dictionary:
	var precheck := precheck_mutation(tool_name, args)
	if not precheck.is_empty():
		return precheck
	return apply_mutation(tool_name, args)

func precheck_mutation(tool_name: String, args: Dictionary) -> Dictionary:
	if not is_mutation_tool(tool_name):
		return AISidebarToolResult.err("UNKNOWN_TOOL", "Not an external scene mutation tool: " + tool_name, false)
	var split := split_mutation_args(args)
	var expected: String = split["expected_scene_path"]
	if expected.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "expected_scene_path is required: the res:// path of the scene to change (scene_file from get_scene_tree).")
	var scene_check := AISidebarSceneTools.confirm_active_scene(expected, 1, scene_root_provider)
	if not scene_check.get("success", false):
		return scene_check
	return {}

func apply_mutation(tool_name: String, args: Dictionary) -> Dictionary:
	var split := split_mutation_args(args)
	var expected_scene_path: String = split["expected_scene_path"]
	var held_before := AISidebarWriterLock.holder() == AISidebarWriterLock.Holder.EXTERNAL
	var lock_err := AISidebarWriterLock.claim(AISidebarWriterLock.Holder.EXTERNAL, tool_name)
	if not lock_err.is_empty():
		return lock_err
	var scene_check := AISidebarSceneTools.confirm_active_scene(expected_scene_path, 1, scene_root_provider)
	if not scene_check.get("success", false):
		if not held_before:
			AISidebarWriterLock.release(AISidebarWriterLock.Holder.EXTERNAL)
		return scene_check
	var tool_args: Dictionary = split["args"]
	return AISidebarToolManager.execute_tool(tool_name, tool_args, false)

func split_mutation_args(args: Dictionary) -> Dictionary:
	var tool_args := args.duplicate(true)
	var expected := str(tool_args.get(EXPECTED_SCENE_ARG, "")).strip_edges()
	tool_args.erase(EXPECTED_SCENE_ARG)
	return {"expected_scene_path": expected, "args": tool_args}

func release_external_writer() -> void:
	AISidebarWriterLock.release(AISidebarWriterLock.Holder.EXTERNAL)

func read_bridge_settings() -> Dictionary:
	var cfg := AISidebarConfig.load_config()
	var port := int(str(cfg.get("mcp_bridge_port", 0)).to_float())
	return {
		"enabled": cfg.get("mcp_bridge_enabled", false) == true,
		"port": port if port > 0 else DEFAULT_PORT,
		"token": str(cfg.get("mcp_bridge_token", "")),
	}

func save_bridge_enabled(enabled: bool) -> Dictionary:
	var cfg := AISidebarConfig.load_config()
	cfg["mcp_bridge_enabled"] = enabled
	if enabled and str(cfg.get("mcp_bridge_token", "")).is_empty():
		cfg["mcp_bridge_token"] = Crypto.new().generate_random_bytes(24).hex_encode()
	if int(str(cfg.get("mcp_bridge_port", 0)).to_float()) <= 0:
		cfg["mcp_bridge_port"] = DEFAULT_PORT
	AISidebarConfig.save_config(cfg)
	return read_bridge_settings()

func server_version() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("res://addons/godot_sidebar_ai/plugin.cfg") == OK:
		return str(cfg.get_value("plugin", "version", "0"))
	return "0"

func _mutation_definition(name: String, description: String, parameters: Dictionary) -> Dictionary:
	var schema: Dictionary = parameters.duplicate(true)
	schema["type"] = "object"
	var props: Dictionary = schema.get("properties", {})
	props[EXPECTED_SCENE_ARG] = {
		"type": "string",
		"description": "res:// path of the scene this change is meant for (the scene_file from get_scene_tree). The call is refused if a different scene is active in the editor.",
	}
	schema["properties"] = props
	var required: Array = schema.get("required", [])
	required.append(EXPECTED_SCENE_ARG)
	schema["required"] = required
	return {
		"name": name,
		"description": description + " For small, precise edits of the scene open in the editor; to build a scene or many nodes, write the .tscn / GDScript yourself and call sync_project instead. Call save_scene before reading the .tscn from disk. Undoable with Ctrl+Z in the editor; refused while another agent is writing (WRITER_BUSY) or when a different scene is open (ACTIVE_SCENE_NOT_CONFIRMED).",
		"inputSchema": schema,
	}

func _sync_project(args: Dictionary) -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "sync_project yalnız editör içinde çalışır.")
	var editor_base: Control = EditorInterface.get_base_control()
	if editor_base == null:
		return AISidebarToolResult.err("EDITOR_REQUIRED", "EditorInterface hazır değil.")
	var editor_tree: SceneTree = editor_base.get_tree()
	var fs := EditorInterface.get_resource_filesystem()
	var started := Time.get_ticks_msec()
	fs.scan()
	await editor_tree.process_frame
	while fs.is_scanning():
		if Time.get_ticks_msec() - started > SYNC_TIMEOUT_MSEC:
			return AISidebarToolResult.err("SYNC_TIMEOUT", "Dosya sistemi taraması %d ms içinde bitmedi." % SYNC_TIMEOUT_MSEC)
		await editor_tree.process_frame
	var changed_value: Variant = args.get("changed_files", [])
	var changed: Array = changed_value if changed_value is Array else []
	var refresh: Dictionary = AISidebarSceneTools.refresh_open_scenes(changed)
	var changed_paths: Array[String] = []
	for path: Variant in changed:
		var changed_path := str(path)
		if not changed_path.is_empty():
			changed_paths.append(changed_path)
	var reloaded_value: Variant = refresh.get("refreshed", [])
	var reloaded: Array = reloaded_value if reloaded_value is Array else []
	return AISidebarToolResult.ok({
		"scanned": true,
		"waited_ms": Time.get_ticks_msec() - started,
		"changed_files_received": changed_paths,
		"changed_file_count": changed_paths.size(),
		"reloaded_open_scenes": reloaded,
	}, "Proje dosya sistemi yeniden tarandı (%d ms); %d değişen dosya bildirildi, %d açık sahne yeniden yüklendi." % [Time.get_ticks_msec() - started, changed_paths.size(), reloaded.size()])
