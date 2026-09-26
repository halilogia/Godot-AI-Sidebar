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

## v3.0 ilk sürüm: okuma, gözlem ve oyun kontrolü. Sahne / dosya değiştiren araçlar dışarıda.
## (Dış ajan dosyaları kendi araçlarıyla yazar, sonra `sync_project` çağırır.)
const EXPOSED_TOOLS: Array[String] = [
	"get_project_files", "search_project_assets", "analyze_project",
	"get_scene_tree", "get_node_properties", "get_selected_nodes", "select_node", "open_scene",
	"read_script", "validate_script",
	"play_game", "stop_game", "restart_game",
	"get_runtime_errors", "inspect_runtime_tree", "inspect_runtime_node",
	"take_editor_screenshot", "take_viewport_screenshot", "take_runtime_screenshot",
	"inspect_ui_layout",
]

## Köprüye özgü araçlar (ToolManager'da yok; sunucu yürütür).
const SYNC_PROJECT_TOOL := {
	"name": "sync_project",
	"description": "Dış bir araç (ör. ajanın kendi dosya yazma aracı) projede dosya oluşturduktan veya değiştirdikten sonra Godot editörüne dosya sistemini yeniden taratır ve tarama bitene kadar bekler. Script / sahne yazdıktan sonra, validate_script veya play_game çağırmadan önce kullanın.",
	"inputSchema": {"type": "object", "properties": {}},
}

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
	out.append(SYNC_PROJECT_TOOL.duplicate(true))
	return out

static func is_exposed(tool_name: String) -> bool:
	return EXPOSED_TOOLS.has(tool_name) or tool_name == SYNC_PROJECT_TOOL["name"]

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
				"instructions": "Godot editor tools from the Godot AI Sidebar plugin. Write files with your own tools, then call sync_project before validate_script / play_game. Use get_runtime_errors and take_runtime_screenshot to verify a running game.",
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
