@tool
extends RefCounted
class_name AISidebarMcpProtocol

## MCP (Model Context Protocol) JSON-RPC katmanı: dış ajanlar (Claude Code, Cursor, Codex…)
## eklentinin araçlarını bu katman üzerinden görür ve çağırır. Soket / HTTP bilmez.
## Araçlar ToolManager üzerinden çalışır; PermissionPolicy, PathPolicy ve doğrulama hattı
## iç ajanla aynıdır (köprü ikinci bir arka kapı değildir). Dışarı yalnızca izin listesindeki
## araçlar açılır.

const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

const SERVER_NAME := "godot-ai-sidebar"
const DEFAULT_PROTOCOL_VERSION := "2025-06-18"

## Okuma, gözlem ve oyun kontrolü. Dosya yazan / silen araçlar dışarıda: dış ajan dosyaları
## kendi araçlarıyla yazar, sonra `sync_project` çağırır. Sahne mutasyonları: MUTATION_TOOLS.
const EXPOSED_TOOLS: Array[String] = [
	"get_project_files", "search_project_assets", "analyze_project",
	"get_scene_tree", "get_node_properties", "get_selected_nodes", "select_node", "open_scene",
	"read_script", "validate_script",
	"play_game", "stop_game", "restart_game", "send_input",
	"get_runtime_errors", "inspect_runtime_tree", "inspect_runtime_node",
	"take_editor_screenshot", "take_viewport_screenshot", "take_runtime_screenshot",
	"inspect_ui_layout",
]

## Sahne mutasyonları: köprü açıksa (`/mcp on`) kullanılabilir; tek aktif yazıcı kilidi geçerlidir.
## Hepsi Undo/Redo'ya kayıtlı. Her çağrı köprüye özgü zorunlu `expected_scene_path` taşır
## (değiştirilecek, editörde açık sahne); ToolManager'a gitmeden args'tan çıkarılır.
## (`instantiate_scene`'in kendi `scene_path`'i örneklenecek kaynak sahnedir; karıştırılmaz.)
const MUTATION_TOOLS: Array[String] = [
	"add_node", "set_node_property", "instantiate_scene", "attach_script_to_node", "save_scene",
]
const EXPECTED_SCENE_ARG := "expected_scene_path"

## Köprüye özgü araçlar (ToolManager'da yok; sunucu yürütür).
const SYNC_PROJECT_TOOL := {
	"name": "sync_project",
	"description": "Call after you create or change project files with your own file tools (GDScript, .tscn, .tres, .gdshader, data files) and before validate_script, play_game or any scene tool. Rescans the Godot editor's file system and waits until the scan ends. List every .tscn you wrote in changed_files: if one of them is the scene open in the editor, it is reloaded from disk so a later save_scene does not overwrite your file with the editor's stale copy.",
	"inputSchema": {"type": "object", "properties": {
		"changed_files": {"type": "array", "items": {"type": "string"}, "description": "res:// paths you created or changed (at least every .tscn)."},
	}},
}

## Dış ajana `initialize` ile verilen çalışma kuralı: üretim dosya-öncelikli, editör etkileşimi
## araç-öncelikli. Köprü yüzeyi normal kod / dosya üretimini kopyalayan üst düzey araçlarla büyütülmez.
const INSTRUCTIONS := "Godot editor tools from the Godot AI Sidebar plugin. If the project has an AGENTS.md at its root, read it first: it holds the project's rules. Construction is file-first: create scripts, scenes (.tscn), resources (.tres), shaders and data files with your own file tools, prefer whole .tscn files or procedural GDScript over many single-node calls, then call sync_project (list the .tscn files in changed_files). Editor interaction is tool-first: use the scene tools (add_node, set_node_property, instantiate_scene, attach_script_to_node, save_scene) only for small, precise, undoable edits of the scene open in the editor; they need an expected_scene_path (scene_file from get_scene_tree). Verify with validate_script, play_game, get_runtime_errors (wait a few seconds after play_game), take_runtime_screenshot, inspect_runtime_tree and inspect_runtime_node (includes script variables); use send_input to press keys, trigger input actions or click nodes in the running game; stop_game when done."

## Dış ajana açılan araç tanımları (MCP `tools/list` biçimi).
static func tool_definitions() -> Array:
	var out: Array = []
	for s: Variant in AISidebarToolManager.get_all_schemas():
		var schema: Dictionary = s
		var fn: Dictionary = schema.get("function", {})
		var name := str(fn.get("name", ""))
		if EXPOSED_TOOLS.has(name):
			out.append({
				"name": name,
				"description": str(fn.get("description", "")),
				"inputSchema": fn.get("parameters", {"type": "object", "properties": {}}),
			})
		elif MUTATION_TOOLS.has(name):
			var params: Dictionary = fn.get("parameters", {})
			out.append(_mutation_definition(name, str(fn.get("description", "")), params))
	out.append(SYNC_PROJECT_TOOL.duplicate(true))
	return out

## Mutasyon aracının şemasına zorunlu `expected_scene_path` eklenir (ToolManager şeması değişmez).
static func _mutation_definition(name: String, description: String, parameters: Dictionary) -> Dictionary:
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

static func is_exposed(tool_name: String) -> bool:
	return EXPOSED_TOOLS.has(tool_name) or MUTATION_TOOLS.has(tool_name) or tool_name == SYNC_PROJECT_TOOL["name"]

static func is_mutation_tool(tool_name: String) -> bool:
	return MUTATION_TOOLS.has(tool_name)

## Köprüye özgü `expected_scene_path`'i araç argümanlarından ayırır.
static func split_mutation_args(args: Dictionary) -> Dictionary:
	var tool_args := args.duplicate(true)
	var expected := str(tool_args.get(EXPECTED_SCENE_ARG, "")).strip_edges()
	tool_args.erase(EXPECTED_SCENE_ARG)
	return {"expected_scene_path": expected, "args": tool_args}

## Tek JSON-RPC mesajını yönlendirir. Dönüş:
##   {"reply": <yanıt sözlüğü>}              → hemen gönderilir
##   {"notification": true}                   → yanıt gövdesi yok (HTTP 202)
##   {"call": {"id", "name", "arguments"}}    → sunucu aracı yürütür, sonra `call_reply` ile yanıtlar
static func route(message: Variant) -> Dictionary:
	if not (message is Dictionary):
		return {"reply": error_reply(null, -32600, "Invalid Request: expected a single JSON-RPC object")}
	var msg: Dictionary = message
	var id: Variant = normalize_id(msg.get("id", null))
	var method := str(msg.get("method", ""))
	if str(msg.get("jsonrpc", "")) != "2.0" or method.is_empty():
		return {"reply": error_reply(id, -32600, "Invalid Request")}
	if not msg.has("id"):
		return {"notification": true}
	var params: Dictionary = msg.get("params", {}) if msg.get("params", {}) is Dictionary else {}
	match method:
		"initialize":
			var requested := str(params.get("protocolVersion", ""))
			return {"reply": result_reply(id, {
				"protocolVersion": requested if not requested.is_empty() else DEFAULT_PROTOCOL_VERSION,
				"capabilities": {"tools": {"listChanged": false}},
				"serverInfo": {"name": SERVER_NAME, "version": plugin_version()},
				"instructions": INSTRUCTIONS,
			})}
		"ping":
			return {"reply": result_reply(id, {})}
		"tools/list":
			return {"reply": result_reply(id, {"tools": tool_definitions()})}
		"tools/call":
			var name := str(params.get("name", ""))
			if not is_exposed(name):
				return {"reply": error_reply(id, -32602, "Unknown or not exposed tool: " + name)}
			var args: Dictionary = params.get("arguments", {}) if params.get("arguments", {}) is Dictionary else {}
			return {"call": {"id": id, "name": name, "arguments": args}}
		_:
			return {"reply": error_reply(id, -32601, "Method not found: " + method)}

## ToolManager ile senkron yürütülebilen araç mı? (async olanlar ve sync_project sunucuda beklenir)
static func is_sync_tool(tool_name: String) -> bool:
	return tool_name != SYNC_PROJECT_TOOL["name"] and not AISidebarToolManager.is_async_tool(tool_name)

## Senkron aracı yürütür (izin politikası iç ajanla aynı; onay gerekiyorsa hata döner).
static func run_sync_tool(tool_name: String, args: Dictionary) -> Dictionary:
	return AISidebarToolManager.execute_tool(tool_name, args, false)

## Araç sonucunu MCP `tools/call` sonucuna çevirir. base64 görsel `image` içeriği olarak
## ayrılır, metin içeriğinden çıkarılır (model görüntüyü görür, JSON şişmez).
static func to_call_result(result: Dictionary) -> Dictionary:
	var content: Array = []
	var shown: Dictionary = result.duplicate(true)
	var data_v: Variant = shown.get("data", null)
	if data_v is Dictionary:
		var data: Dictionary = data_v  # aynı sözlük: silme `shown`'a yansır
		var b64 := str(data.get("base64", ""))
		if not b64.is_empty():
			content.append({"type": "image", "data": b64, "mimeType": "image/png"})
			data.erase("base64")
	content.push_front({"type": "text", "text": JSON.stringify(shown)})
	var ok: bool = result.get("success", false) == true
	return {"content": content, "isError": not ok}

static func call_reply(id: Variant, result: Dictionary) -> Dictionary:
	return result_reply(id, to_call_result(result))

## Godot JSON sayıları float çözer (1 → 1.0); JSON-RPC istemcisine id aynen (tam sayı) dönmeli.
static func normalize_id(id: Variant) -> Variant:
	if id is float:
		var f: float = id
		if is_finite(f) and f == floorf(f):
			return int(f)
	return id

static func result_reply(id: Variant, result: Dictionary) -> Dictionary:
	return {"jsonrpc": "2.0", "id": id, "result": result}

static func error_reply(id: Variant, code: int, message: String) -> Dictionary:
	return {"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}}

static func plugin_version() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("res://addons/godot_sidebar_ai/plugin.cfg") == OK:
		return str(cfg.get_value("plugin", "version", "0"))
	return "0"

## Basit hata sonucu (ToolResult biçiminde) — sunucu tarafı hatalar için.
static func failure(code: String, message: String) -> Dictionary:
	return AISidebarToolResult.err(code, message)
