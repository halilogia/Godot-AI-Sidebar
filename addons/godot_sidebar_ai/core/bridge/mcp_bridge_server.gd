@tool
extends Node
class_name AISidebarMcpBridgeServer

## Dış ajan köprüsü (v3.0): editör içinde yalnız 127.0.0.1'de dinleyen, token korumalı
## MCP Streamable HTTP uç noktası (`POST /mcp`). Claude Code bağlanır:
##   claude mcp add --transport http godot http://127.0.0.1:<port>/mcp --header "Authorization: Bearer <token>"
## Varsayılan kapalı; sidebar'da `/mcp on` ile açılır. Port ve token config.json'da kalıcıdır.
## Güvenlik: yalnız loopback, Bearer token zorunlu, `Origin` başlıklı (tarayıcı) istekler
## reddedilir, araçlar AISidebarMcpProtocol izin listesi + ToolManager politikalarından geçer.

const AISidebarMcpHttp = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_http.gd")
const AISidebarMcpProtocol = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_protocol.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

const DEFAULT_PORT := 6570
const IDLE_TIMEOUT_MSEC := 10000
const SYNC_TIMEOUT_MSEC := 30000

## Tek HTTP bağlantısı (istek başına bir bağlantı; yanıttan sonra kapanır).
class Client:
	var peer: StreamPeerTCP
	var buffer: PackedByteArray = PackedByteArray()
	var busy: bool = false
	var since_msec: int = 0

	func _init(p_peer: StreamPeerTCP) -> void:
		peer = p_peer
		since_msec = Time.get_ticks_msec()

## Editördeki tek köprü (slash komutu buradan ulaşır). Testler kendi örneklerini kurar.
static var instance: AISidebarMcpBridgeServer = null

var port: int = 0
var token: String = ""
var _server: TCPServer = null
var _clients: Array[Client] = []

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	stop()
	if instance == self:
		instance = null

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
	var routed := AISidebarMcpProtocol.route(parsed)
	if routed.has("notification"):
		return AISidebarMcpHttp.build_response(202)
	if routed.has("reply"):
		return _json(200, routed["reply"])
	var call: Dictionary = routed["call"]
	var call_args: Dictionary = call["arguments"]
	var result: Dictionary = await run_tool(str(call["name"]), call_args)
	var ok: bool = result.get("success", false)
	print("[Godot AI MCP] %s -> %s" % [call["name"], "ok" if ok else "error"])
	return _json(200, AISidebarMcpProtocol.call_reply(call["id"], result))

## İzin listesindeki aracı yürütür (sync_project köprüye özgü).
func run_tool(tool_name: String, args: Dictionary) -> Dictionary:
	if tool_name == "sync_project":
		return await _sync_project()
	if AISidebarMcpProtocol.is_sync_tool(tool_name):
		return AISidebarMcpProtocol.run_sync_tool(tool_name, args)
	return await AISidebarToolManager.execute_tool_async(tool_name, args, false)

func _sync_project() -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface") or not is_inside_tree():
		return AISidebarToolResult.err("EDITOR_REQUIRED", "sync_project yalnız editör içinde çalışır.")
	var fs := EditorInterface.get_resource_filesystem()
	var started := Time.get_ticks_msec()
	fs.scan()
	await get_tree().process_frame
	while fs.is_scanning():
		if Time.get_ticks_msec() - started > SYNC_TIMEOUT_MSEC:
			return AISidebarToolResult.err("SYNC_TIMEOUT", "Dosya sistemi taraması %d ms içinde bitmedi." % SYNC_TIMEOUT_MSEC)
		await get_tree().process_frame
	return AISidebarToolResult.ok({"scanned": true, "waited_ms": Time.get_ticks_msec() - started}, "Proje dosya sistemi yeniden tarandı.")

func _json(status: int, body: Variant) -> PackedByteArray:
	return AISidebarMcpHttp.build_response(status, JSON.stringify(body))

## Kayıtlı köprü ayarları (config.json'a yazmaz).
static func read_settings() -> Dictionary:
	var cfg := AISidebarConfig.load_config()
	var p: int = int(str(cfg.get("mcp_bridge_port", 0)).to_float())
	var enabled: bool = cfg.get("mcp_bridge_enabled", false) == true
	return {
		"enabled": enabled,
		"port": p if p > 0 else DEFAULT_PORT,
		"token": str(cfg.get("mcp_bridge_token", "")),
	}

## Köprüyü açık / kapalı olarak kaydeder; açarken token ve port yoksa üretir.
static func save_enabled(enabled: bool) -> Dictionary:
	var cfg := AISidebarConfig.load_config()
	cfg["mcp_bridge_enabled"] = enabled
	if enabled and str(cfg.get("mcp_bridge_token", "")).is_empty():
		cfg["mcp_bridge_token"] = Crypto.new().generate_random_bytes(24).hex_encode()
	if int(str(cfg.get("mcp_bridge_port", 0)).to_float()) <= 0:
		cfg["mcp_bridge_port"] = DEFAULT_PORT
	AISidebarConfig.save_config(cfg)
	return read_settings()

## Kayıtlı ayara göre dinlemeye başlar (kapalıysa bir şey yapmaz). Dönüş Godot Error.
func start_from_settings() -> int:
	var s := read_settings()
	var enabled: bool = s["enabled"]
	if not enabled:
		return OK
	var p: int = s["port"]
	var t: String = s["token"]
	return start(p, t)
