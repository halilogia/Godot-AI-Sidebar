@tool
extends Node
class_name AISidebarMcpBridgeControl

## Editor lifecycle facade used by the plugin composition root and /mcp command.
const AISidebarExternalAgentGateway = preload("res://addons/godot_sidebar_ai/core/bridge/external_agent_gateway.gd")
const AISidebarMcpProtocol = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_protocol.gd")
const AISidebarMcpBridgeServer = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_bridge_server.gd")

static var instance: AISidebarMcpBridgeControl
var gateway: AISidebarExternalAgentGateway
var protocol: AISidebarMcpProtocol
var server: AISidebarMcpBridgeServer

func _init() -> void:
	gateway = AISidebarExternalAgentGateway.new()
	protocol = AISidebarMcpProtocol.new(gateway)
	server = AISidebarMcpBridgeServer.new(protocol)

func _enter_tree() -> void:
	instance = self
	server.name = "GodotAIMcpBridgeServer"
	add_child(server)
	var settings := gateway.read_bridge_settings()
	var result: int = OK
	if settings["enabled"]:
		var saved_port: int = str(settings.get("port", "0")).to_int()
		var saved_token: String = str(settings.get("token", ""))
		result = server.start(saved_port, saved_token)
	if result != OK:
		push_warning("[Godot AI MCP] Köprü açılamadı (hata %d). Port başka bir süreçte kullanılıyor olabilir." % result)

func _exit_tree() -> void:
	server.stop()
	gateway.release_external_writer()
	if instance == self:
		instance = null

func tool_count() -> int:
	return gateway.tool_definitions().size()

func set_enabled(enabled: bool) -> Dictionary:
	return gateway.save_bridge_enabled(enabled)

func endpoint() -> String:
	return server.endpoint()

func bearer_token() -> String:
	return server.token

func is_running() -> bool:
	return server.is_running()

func start(port: int, bearer_token: String) -> int:
	return server.start(port, bearer_token)

func stop() -> void:
	server.stop()
	gateway.release_external_writer()

func claude_add_command() -> String:
	return server.claude_add_command()

## Köprüyü açık olarak kaydeder ve başlatır (/mcp on ve Ayarlar → Dış Ajan). Dönüş: {ok, port, error}
func enable() -> Dictionary:
	var s := set_enabled(true)
	var p: int = s["port"]
	var err := start(p, str(s["token"]))
	return {"ok": err == OK, "port": p, "error": err}

## Köprüyü kapalı olarak kaydeder ve durdurur (/mcp off ve Ayarlar → Dış Ajan).
func disable() -> void:
	set_enabled(false)
	stop()

func saved_port() -> int:
	var p: int = gateway.read_bridge_settings()["port"]
	return p

## Portu kaydeder; köprü açıksa yeni portta yeniden başlatır. Dönüş: enable() gibi ya da {ok: true}.
func change_port(port: int) -> Dictionary:
	gateway.save_bridge_port(port)
	if is_running():
		stop()
		return enable()
	return {"ok": true, "port": saved_port(), "error": OK}

## Bağlantı komutu, token'ın yalnız ilk 4 karakteri görünür biçimde (sohbete / arayüze yazmak için).
func masked_claude_add_command() -> String:
	var token_value := bearer_token()
	return claude_add_command().replace(token_value, token_value.left(4) + "…")
