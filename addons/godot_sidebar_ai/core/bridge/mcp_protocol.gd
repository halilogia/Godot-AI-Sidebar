@tool
extends RefCounted
class_name AISidebarMcpProtocol

## MCP / JSON-RPC message handling and MCP result formatting. It knows Godot capabilities
## only through AISidebarExternalAgentGateway and has no transport or editor implementation.

const AISidebarExternalAgentGateway = preload("res://addons/godot_sidebar_ai/core/bridge/external_agent_gateway.gd")

const SERVER_NAME := "godot-ai-sidebar"
const DEFAULT_PROTOCOL_VERSION := "2025-06-18"
## En yeni ilk: 2026-07-28 durumsuz (initialize yok, `server/discover`, istek başına _meta sürümü); eski istemciler
## initialize ile bağlanmaya devam eder.
const SUPPORTED_VERSIONS: Array[String] = ["2026-07-28", "2025-11-25", "2025-06-18", "2025-03-26"]
const META_VERSION := "io.modelcontextprotocol/protocolVersion"
const ERR_HEADER_MISMATCH := -32020
const ERR_UNSUPPORTED_VERSION := -32022
const TOOLS_LIST_TTL_MS := 300000

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
	var meta: Dictionary = params.get("_meta", {}) if params.get("_meta", {}) is Dictionary else {}
	var meta_version := str(meta.get(META_VERSION, ""))
	if not meta_version.is_empty() and not meta_version in SUPPORTED_VERSIONS:
		return {"reply": unsupported_version_reply(id, meta_version)}
	match method:
		"initialize":
			var requested := str(params.get("protocolVersion", ""))
			var negotiated := requested if requested in SUPPORTED_VERSIONS else DEFAULT_PROTOCOL_VERSION
			return {"reply": result_reply(id, {
				"protocolVersion": negotiated,
				"capabilities": {"tools": {"listChanged": false}},
				"serverInfo": {"name": SERVER_NAME, "version": _gateway.server_version()},
				"instructions": _gateway.instructions(),
			})}
		"server/discover":
			return {"reply": result_reply(id, {
				"supportedVersions": SUPPORTED_VERSIONS,
				"capabilities": {"tools": {"listChanged": false}},
				"serverInfo": {"name": SERVER_NAME, "version": _gateway.server_version()},
				"instructions": _gateway.instructions(),
			})}
		"ping":
			return {"reply": result_reply(id, {})}
		"tools/list":
			return {"reply": result_reply(id, {"tools": _gateway.tool_definitions(), "ttlMs": TOOLS_LIST_TTL_MS, "cacheScope": "private"})}
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
	var shown_v: Variant = scrub_value(result.duplicate(true))
	var shown: Dictionary = shown_v
	var data_v: Variant = shown.get("data", null)
	if data_v is Dictionary:
		var data: Dictionary = data_v  # aynı sözlük: silme `shown`'a yansır
		var b64 := str(data.get("base64", ""))
		if not b64.is_empty():
			content.append({"type": "image", "data": b64, "mimeType": "image/png"})
			data.erase("base64")
	content.push_front({"type": "text", "text": JSON.stringify(shown)})
	var ok: bool = result.get("success", false) == true
	# structuredContent: aynı sonuç makinece okunur biçimde (ekran görüntüsü base64'ü hariç).
	return {"content": content, "structuredContent": shown, "isError": not ok}

## Godot çıktısındaki ANSI renk dizileri ve denetim karakterleri (ör. ESC) JSON'a kaçışsız girip istemcinin
## ayrıştırmasını bozuyordu (get_output): renk dizileri atılır, satır sonu ve sekme dışındaki denetim karakterleri silinir.
static func scrub_value(v: Variant) -> Variant:
	if v is String:
		var text: String = v
		return scrub_text(text)
	if v is Array:
		var arr: Array = v
		for i in arr.size():
			arr[i] = scrub_value(arr[i])
		return arr
	if v is Dictionary:
		var d: Dictionary = v
		for k: Variant in d.keys():
			d[k] = scrub_value(d[k])
		return d
	return v

static func scrub_text(text: String) -> String:
	var rx := RegEx.new()
	rx.compile("\u001b\\[[0-9;]*[A-Za-z]")
	var out := rx.sub(text, "", true)
	var clean := PackedStringArray()
	for i in out.length():
		var c := out.unicode_at(i)
		if c >= 32 or c == 9 or c == 10 or c == 13:
			clean.append(out[i])
	return "".join(clean)

static func call_reply(id: Variant, result: Dictionary) -> Dictionary:
	return result_reply(id, to_call_result(result))

## Godot JSON sayıları float çözer (1 → 1.0); JSON-RPC istemcisine id aynen (tam sayı) dönmeli.
static func normalize_id(id: Variant) -> Variant:
	if id is float:
		var f: float = id
		if is_finite(f) and f == floorf(f):
			return int(f)
	return id

## Her sonuç `resultType` taşır ("complete"; 2026-07-28), sunucu kimliği _meta'da.
static func result_reply(id: Variant, result: Dictionary) -> Dictionary:
	var out := result.duplicate()
	if not out.has("resultType"):
		out["resultType"] = "complete"
	var meta: Dictionary = out.get("_meta", {}) if out.get("_meta", {}) is Dictionary else {}
	meta["io.modelcontextprotocol/serverInfo"] = {"name": SERVER_NAME}
	out["_meta"] = meta
	return {"jsonrpc": "2.0", "id": id, "result": out}

static func unsupported_version_reply(id: Variant, requested: String) -> Dictionary:
	var reply := error_reply(id, ERR_UNSUPPORTED_VERSION, "Unsupported protocol version: " + requested)
	var err: Dictionary = reply["error"]
	err["data"] = {"supported": SUPPORTED_VERSIONS, "requested": requested}
	return reply

## HTTP başlıkları gövdeyle uyuşmalı (Mcp-Method, Mcp-Name, MCP-Protocol-Version): uyuşmazlık 400 + -32020,
## desteklenmeyen sürüm 400 + -32022. Başlık yoksa sorun sayılmaz (eski istemciler göndermez).
static func validate_headers(message: Variant, headers: Dictionary) -> Dictionary:
	if not (message is Dictionary):
		return {}
	var msg: Dictionary = message
	var id: Variant = normalize_id(msg.get("id", null))
	var method := str(msg.get("method", ""))
	var version := str(headers.get("mcp-protocol-version", ""))
	if not version.is_empty() and not version in SUPPORTED_VERSIONS:
		return unsupported_version_reply(id, version)
	var h_method := str(headers.get("mcp-method", ""))
	if not h_method.is_empty() and h_method != method:
		return error_reply(id, ERR_HEADER_MISMATCH, "HeaderMismatch: Mcp-Method '%s' does not match the request method '%s'" % [h_method, method])
	var h_name := str(headers.get("mcp-name", ""))
	if not h_name.is_empty() and method == "tools/call":
		var params: Dictionary = msg.get("params", {}) if msg.get("params", {}) is Dictionary else {}
		if h_name != str(params.get("name", "")):
			return error_reply(id, ERR_HEADER_MISMATCH, "HeaderMismatch: Mcp-Name '%s' does not match the tool name '%s'" % [h_name, str(params.get("name", ""))])
	return {}

static func error_reply(id: Variant, code: int, message: String) -> Dictionary:
	return {"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}}
