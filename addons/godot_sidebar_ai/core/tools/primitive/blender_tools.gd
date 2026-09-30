@tool
extends RefCounted
class_name AISidebarBlenderTools

## `blender_tools` (Blender'ın araç listesi / bir aracın şeması, salt okunur) ve `blender_call` (bir Blender aracını
## çalıştırır): 3B model, prop, karakter ve animasyon Blender Copilot ile yapılır, `.glb` olarak projeye gelir.
## İkisi de yalnız Ayarlar → Blender'da köprü açıksa sunulur. Kaynak ajanın iki genel aracıdır; Blender'ın 40 aracı
## tek tek şema olarak bağlama girmez (`blender_tools` ile istenince okunur).

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarBlenderClient = preload("res://addons/godot_sidebar_ai/core/bridge/blender_client.gd")

const LIST_TOOL := "blender_tools"
const CALL_TOOL := "blender_call"
const IMPORT_DIR := "res://assets/blender"
const LIST_TIMEOUT_SEC := 15.0
const CALL_TIMEOUT_SEC := 600.0

static func settings() -> Dictionary:
	return AISidebarBlenderClient.settings_from(AISidebarConfig.load_config())

static func is_enabled() -> bool:
	return settings()["enabled"] == true

static func is_blender_tool(tool_name: String) -> bool:
	return tool_name == LIST_TOOL or tool_name == CALL_TOOL

static func get_schemas() -> Array:
	if not is_enabled():
		return []
	return [
		{
			"type": "function",
			"function": {
				"name": LIST_TOOL,
				"description": "Lists the Blender tools (Blender Copilot) you can run with blender_call: one line each. With `name`, returns that tool's full description and argument schema. Read a tool's schema before its first blender_call.",
				"parameters": {
					"type": "object",
					"properties": {
						"name": {"type": "string", "description": "Optional: a Blender tool name to read in full."},
					},
					"required": [],
				},
			},
		},
		{
			"type": "function",
			"function": {
				"name": CALL_TOOL,
				"description": "Runs one Blender tool. Use Blender for 3D models, props, characters and animation instead of building shapes from code: create_prop makes a crate, tree, house, car, person or robot in one call; set_material (preset wood, stone, brick, metal ...), rig_character and animate_character; then export_gltf writes a .glb, which this call copies into res://assets/blender/ and returns as `godot_path`. Use that path in a .tscn as a PackedScene ext_resource (1 unit = 1 meter, Y up). Shader-node materials do not survive glTF: bake_material paints them into a texture first (or use flat colours). Renders and exports can take minutes. Blender's own errors come back as-is: read them and fix the arguments.",
				"parameters": {
					"type": "object",
					"properties": {
						"tool": {"type": "string", "description": "Blender tool name from blender_tools."},
						"arguments": {"type": "object", "description": "Arguments of that tool, exactly as its schema names them."},
					},
					"required": ["tool"],
				},
			},
		},
	]

## Blender'ın bir .glb'sini projeye alır: res://assets/blender/<dosya>. Dönüş: {ok, godot_path | error}.
static func import_glb(source: String) -> Dictionary:
	if not FileAccess.file_exists(source):
		return {"ok": false, "error": "Blender wrote %s but Godot cannot read it (Blender may run on another computer or user)." % source}
	var file_name := source.get_file()
	var safe := ""
	for i in file_name.length():
		var c := file_name[i]
		safe += c if (c.unicode_at(0) < 128 and (c == "." or c == "_" or c == "-" or c.is_valid_identifier() or c.is_valid_int())) else "_"
	if safe.is_empty() or safe.begins_with("."):
		safe = "model.glb"
	var dest := IMPORT_DIR + "/" + safe
	var abs_dir := ProjectSettings.globalize_path(IMPORT_DIR)
	if DirAccess.make_dir_recursive_absolute(abs_dir) != OK:
		return {"ok": false, "error": "Could not create " + IMPORT_DIR}
	if DirAccess.copy_absolute(source, ProjectSettings.globalize_path(dest)) != OK:
		return {"ok": false, "error": "Could not copy the file to " + dest}
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	return {"ok": true, "godot_path": dest}

static func unreachable_message(detail: String) -> String:
	return "%s Open Blender, start the add-on's MCP bridge (3D Viewport, N panel, Blender - Copilot, MCP bridge, Start), then set the address and token in Settings > Blender." % detail

static func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	var cfg := settings()
	if cfg["enabled"] != true:
		return AISidebarToolResult.err("BLENDER_DISABLED", "The Blender bridge is off. The user can turn it on in Settings > Blender.")
	if str(cfg["token"]).is_empty():
		return AISidebarToolResult.err("BLENDER_TOKEN_MISSING", "No Blender bridge token yet: the user must copy it from the add-on panel into Settings > Blender.")
	if tool_name == LIST_TOOL:
		return await _list(cfg, str(args.get("name", "")).strip_edges())
	if tool_name == CALL_TOOL:
		return await _call(cfg, str(args.get("tool", "")).strip_edges(), args.get("arguments", {}))
	return AISidebarToolResult.err("UNKNOWN_TOOL", "Unknown Blender tool: " + tool_name)

static func _list(cfg: Dictionary, name: String) -> Dictionary:
	var reply: Dictionary = await AISidebarBlenderClient.request_async(cfg, "tools/list", {}, LIST_TIMEOUT_SEC)
	if reply.get("ok", false) != true:
		return _failure(reply)
	var result := AISidebarBlenderClient.as_dict(reply.get("result", {}))
	if name.is_empty():
		var tools := AISidebarBlenderClient.summarize_tools(result)
		return AISidebarToolResult.ok({"count": tools.size(), "tools": tools}, "%d Blender tools." % tools.size())
	var tool := AISidebarBlenderClient.find_tool(result, name)
	if tool.is_empty():
		return AISidebarToolResult.err("BLENDER_TOOL_NOT_FOUND", "Blender has no tool named '%s'. Call blender_tools without a name to see them." % name)
	return AISidebarToolResult.ok({"name": name, "description": str(tool.get("description", "")), "input_schema": tool.get("inputSchema", {})}, "Schema of " + name)

static func _call(cfg: Dictionary, tool: String, arguments: Variant) -> Dictionary:
	if tool.is_empty():
		return AISidebarToolResult.err("BLENDER_TOOL_MISSING", "Give the Blender tool name in `tool` (see blender_tools).")
	if not arguments is Dictionary:
		return AISidebarToolResult.err("BLENDER_ARGUMENTS_INVALID", "`arguments` must be an object.")
	var reply: Dictionary = await AISidebarBlenderClient.request_async(cfg, "tools/call", {"name": tool, "arguments": arguments}, CALL_TIMEOUT_SEC)
	if reply.get("ok", false) != true:
		return _failure(reply)
	var unwrapped := AISidebarBlenderClient.unwrap_call(AISidebarBlenderClient.as_dict(reply.get("result", {})))
	if unwrapped.get("success", false) != true:
		var err: Variant = unwrapped.get("error", null)
		var msg := JSON.stringify(err) if err != null else "Blender reported a failure."
		return AISidebarToolResult.err("BLENDER_TOOL_FAILED", AISidebarBlenderClient.clip("%s failed in Blender: %s" % [tool, msg]), true, unwrapped.get("data", null))
	var data := AISidebarBlenderClient.as_dict(unwrapped.get("data", {}))
	var glb := AISidebarBlenderClient.glb_path_of(unwrapped)
	if not glb.is_empty():
		var imported := import_glb(glb)
		if imported.get("ok", false) == true:
			data["godot_path"] = imported["godot_path"]
		else:
			data["import_error"] = imported["error"]
	var shown := JSON.stringify(data)
	if shown.length() > AISidebarBlenderClient.MAX_RESULT_CHARS:
		return AISidebarToolResult.ok({"result_text": AISidebarBlenderClient.clip(shown)}, tool + " done.")
	return AISidebarToolResult.ok(data, tool + " done.")

static func _failure(reply: Dictionary) -> Dictionary:
	var msg := str(reply.get("error", "Unknown error."))
	if reply.get("unreachable", false) == true:
		return AISidebarToolResult.err("BLENDER_UNREACHABLE", unreachable_message(msg))
	return AISidebarToolResult.err("BLENDER_ERROR", msg)
