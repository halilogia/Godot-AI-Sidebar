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
