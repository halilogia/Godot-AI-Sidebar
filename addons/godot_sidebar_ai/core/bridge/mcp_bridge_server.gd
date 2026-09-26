@tool
extends Node
class_name AISidebarMcpBridgeServer

## Dış ajan köprüsü (v3.0): editör içinde yalnız 127.0.0.1'de dinleyen, token korumalı
## MCP Streamable HTTP uç noktası (`POST /mcp`). Claude Code bağlanır:
##   claude mcp add --transport http godot http://127.0.0.1:<port>/mcp --header "Authorization: Bearer <token>"
## Varsayılan kapalı; sidebar'da `/mcp on` ile açılır. Port ve token config.json'da kalıcıdır.
## Güvenlik: yalnız loopback, Bearer token zorunlu ve `Origin` başlıklı istekler reddedilir.

const AISidebarMcpHttp = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_http.gd")
const AISidebarMcpProtocol = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_protocol.gd")

const IDLE_TIMEOUT_MSEC := 10000

## Tek HTTP bağlantısı (istek başına bir bağlantı; yanıttan sonra kapanır).
class Client:
	var peer: StreamPeerTCP
	var buffer: PackedByteArray = PackedByteArray()
	var busy: bool = false
	var since_msec: int = 0

	func _init(p_peer: StreamPeerTCP) -> void:
		peer = p_peer
		since_msec = Time.get_ticks_msec()

var port: int = 0
var token: String = ""
var protocol: AISidebarMcpProtocol
var _server: TCPServer = null
var _clients: Array[Client] = []

func _init(p_protocol: AISidebarMcpProtocol = null) -> void:
	protocol = p_protocol

func _exit_tree() -> void:
	stop()

func _process(_delta: float) -> void:
	poll()

## Dinlemeye başlar. Dönüş Godot Error (OK = 0).
func start(p_port: int, p_token: String) -> int:
	stop()
	if p_token.is_empty():
		return ERR_UNAUTHORIZED
	var srv := TCPServer.new()
	var err := srv.listen(p_port, "127.0.0.1")
	if err != OK:
		return err
	_server = srv
	port = p_port
	token = p_token
	set_process(true)
	print("[Godot AI MCP] Köprü açık: http://127.0.0.1:%d/mcp" % port)
	return OK

func stop() -> void:
	for c: Client in _clients:
		c.peer.disconnect_from_host()
	_clients.clear()
	if _server:
		_server.stop()
		_server = null
		print("[Godot AI MCP] Köprü kapatıldı.")

func is_running() -> bool:
	return _server != null and _server.is_listening()

func endpoint() -> String:
	return "http://127.0.0.1:%d/mcp" % port

## Claude Code'a bağlanmak için hazır komut.
func claude_add_command() -> String:
	return "claude mcp add --transport http godot %s --header \"Authorization: Bearer %s\"" % [endpoint(), token]

## Bağlantıları kabul eder ve tamamlanan istekleri işler (her karede; testler elle çağırır).
func poll() -> void:
	if _server == null:
		return
	while _server.is_connection_available():
		_clients.append(Client.new(_server.take_connection()))
	for c: Client in _clients.duplicate():
		c.peer.poll()
		if c.peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_clients.erase(c)
			continue
		if c.busy:
			continue
		var avail := c.peer.get_available_bytes()
		if avail > 0:
			var got: Array = c.peer.get_partial_data(avail)
			var got_err: int = got[0]
			var got_bytes: PackedByteArray = got[1]
			if got_err == OK:
				c.buffer.append_array(got_bytes)
		if c.buffer.is_empty():
			if Time.get_ticks_msec() - c.since_msec > IDLE_TIMEOUT_MSEC:
				c.peer.disconnect_from_host()
				_clients.erase(c)
			continue
		var req := AISidebarMcpHttp.parse_request(c.buffer)
		var complete: bool = req.get("complete", false)
		if not complete:
			continue
		c.busy = true
		_serve(c, req)

func _serve(c: Client, req: Dictionary) -> void:
	var response: PackedByteArray = await respond(req)
	if c.peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		c.peer.put_data(response)
		c.peer.disconnect_from_host()
	_clients.erase(c)

## Ayrıştırılmış isteğe HTTP yanıtı üretir (araç çağrısı ise yürütür).
func respond(req: Dictionary) -> PackedByteArray:
	if req.has("error_status"):
		var status: int = req["error_status"]
		return _json(status, {"error": str(req.get("error", ""))})
	var headers: Dictionary = req.get("headers", {})
	if str(req.get("path", "")).split("?")[0] != "/mcp":
		return _json(404, {"error": "Not found; the MCP endpoint is /mcp"})
	if not str(headers.get("origin", "")).is_empty():
		return _json(403, {"error": "Browser-origin requests are not allowed"})
	if str(headers.get("authorization", "")) != "Bearer " + token:
		return _json(401, {"error": "Missing or invalid bearer token"})
	if str(req.get("method", "")) != "POST":
		return AISidebarMcpHttp.build_response(405, "", "application/json", {"Allow": "POST"})
	var parsed: Variant = JSON.parse_string(str(req.get("body", "")))
	if parsed == null:
		return _json(400, AISidebarMcpProtocol.error_reply(null, -32700, "Parse error"))
	if protocol == null:
		return _json(500, {"error": "MCP protocol handler is unavailable"})
	var routed := protocol.route(parsed)
	if routed.has("notification"):
		return AISidebarMcpHttp.build_response(202)
	if routed.has("reply"):
		return _json(200, routed["reply"])
	var call: Dictionary = routed["call"]
	var reply: Dictionary = await protocol.complete_call(call)
	var result_value: Variant = reply.get("result", {})
	var result: Dictionary = result_value if result_value is Dictionary else {}
	var is_error: Variant = result.get("isError", false)
	var ok: bool = is_error != true
	print("[Godot AI MCP] %s -> %s" % [call["name"], "ok" if ok else "error"])
	return _json(200, reply)

func _json(status: int, body: Variant) -> PackedByteArray:
	return AISidebarMcpHttp.build_response(status, JSON.stringify(body))
