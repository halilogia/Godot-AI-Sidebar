@tool
extends RefCounted
class_name AISidebarMcpProtocol

## MCP / JSON-RPC message handling and MCP result formatting. It knows Godot capabilities
## only through AISidebarExternalAgentGateway and has no transport or editor implementation.

const AISidebarExternalAgentGateway = preload("res://addons/godot_sidebar_ai/core/bridge/external_agent_gateway.gd")

const SERVER_NAME := "godot-ai-sidebar"
const DEFAULT_PROTOCOL_VERSION := "2025-06-18"

var _gateway: AISidebarExternalAgentGateway

func _init(gateway: AISidebarExternalAgentGateway) -> void:
	_gateway = gateway

## Tek JSON-RPC mesajını yönlendirir. Dönüş:
##   {"reply": <yanıt sözlüğü>}              → hemen gönderilir
##   {"notification": true}                   → yanıt gövdesi yok (HTTP 202)
##   {"call": {"id", "name", "arguments"}}    → sunucu aracı yürütür, sonra `call_reply` ile yanıtlar
func route(message: Variant) -> Dictionary:
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
				"serverInfo": {"name": SERVER_NAME, "version": _gateway.server_version()},
				"instructions": _gateway.instructions(),
			})}
		"ping":
			return {"reply": result_reply(id, {})}
		"tools/list":
			return {"reply": result_reply(id, {"tools": _gateway.tool_definitions()})}
		"tools/call":
			var name := str(params.get("name", ""))
			if not _gateway.is_tool_exposed(name):
				return {"reply": error_reply(id, -32602, "Unknown or not exposed tool: " + name)}
			var args: Dictionary = params.get("arguments", {}) if params.get("arguments", {}) is Dictionary else {}
			return {"call": {"id": id, "name": name, "arguments": args}}
		_:
			return {"reply": error_reply(id, -32601, "Method not found: " + method)}

## Complete a validated MCP tools/call request via the Godot capability boundary.
func complete_call(call: Dictionary) -> Dictionary:
	var arguments_value: Variant = call.get("arguments", {})
	var arguments: Dictionary = arguments_value if arguments_value is Dictionary else {}
	var result: Dictionary = await _gateway.dispatch(str(call.get("name", "")), arguments)
	return call_reply(call.get("id", null), result)

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
