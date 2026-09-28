@tool
extends EditorPlugin

const AISidebarEditorSmoke = preload("res://addons/godot_sidebar_ai/core/dev/editor_smoke.gd")
const AISidebarDemoBench = preload("res://addons/godot_sidebar_ai/core/dev/demo_bench.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const DOCK_SCENE_PATH: String = "res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn"
const AISidebarUITelemetryTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd")
const AISidebarDebuggerPlugin = preload("res://addons/godot_sidebar_ai/core/runtime/debugger_plugin.gd")
const AISidebarAgentHost = preload("res://addons/godot_sidebar_ai/core/agent/agent_host.gd")
const AISidebarMcpBridgeControl = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_bridge_control.gd")
const AISidebarProjectSettingsTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/project_settings_tools.gd")

var chat_dock: Control = null
var debugger_plugin: AISidebarDebuggerPlugin = null
## Kompozisyon kökü: ajan katmanı (NetworkManager, provider, context, runner) burada kurulur
## ve dock'a enjekte edilir; UI altyapıyı kendisi kurmaz.
var agent_host: AISidebarAgentHost = null
## Dış ajan köprüsü (MCP); varsayılan kapalı, `/mcp on` ile açılır.
var mcp_bridge: AISidebarMcpBridgeControl = null

func _enter_tree() -> void:
	# Sağlayıcı profilleri kullanıcı düzeyinde (bütün projeler): yalnız normal oturumda (dock ilk ayar yüklemesinden
	# önce açılır); duman testi ve benchmark editörleri kullanıcının dosyasına yazmaz.
	AISidebarConfig.global_store_enabled = AISidebarEditorSmoke.requested_out_dir().is_empty() and AISidebarDemoBench.requested_out_dir().is_empty()
	# 1. Hata Ayıklayıcı Eklentisi & Runtime Bridge
	debugger_plugin = AISidebarDebuggerPlugin.new()
	add_debugger_plugin(debugger_plugin)
	add_autoload_singleton("GodotAIRuntimeBridge", "res://addons/godot_sidebar_ai/core/runtime/runtime_bridge.gd")
	# manage_project_settings autoload'ı editörün kendi yoluyla ekler (betikler adı hemen tanısın).
	AISidebarProjectSettingsTools.editor_plugin = self

	# 2. Sidebar Dock (arayüz editörün ölçeğiyle büyür: yazı, boşluk, ikon)
	AISidebarTheme.ui_scale = EditorInterface.get_editor_scale()
	# Açık / koyu editör teması: palet editörün temel renginden seçilir, tema değişince panel yeniden boyanır.
	AISidebarTheme.use_editor_palette()
	var es := EditorInterface.get_editor_settings()
	if es and not es.settings_changed.is_connected(_on_editor_settings_changed):
		es.settings_changed.connect(_on_editor_settings_changed)
	if ResourceLoader.exists(DOCK_SCENE_PATH):
		var dock_scene: PackedScene = load(DOCK_SCENE_PATH)
		if dock_scene:
			agent_host = AISidebarAgentHost.new()
			agent_host.name = "GodotAIAgentHost"
			add_child(agent_host)
			chat_dock = dock_scene.instantiate()
			chat_dock.name = "GodotAISidebar"
			chat_dock.agent_host = agent_host
			add_control_to_dock(DOCK_SLOT_RIGHT_UL, chat_dock)
			AISidebarUITelemetryTools.register_sidebar_dock(chat_dock)
			print("[Godot AI Core] Eklenti başarıyla yüklendi (Sağ Dock).")

	# 2b. Editör duman testi: yalnız `-- --ai-sidebar-smoke=<klasör>` ile açılınca (tools/editor_smoke.ps1).
	var smoke_dir := AISidebarEditorSmoke.requested_out_dir()
	if not smoke_dir.is_empty() and chat_dock:
		var smoke := AISidebarEditorSmoke.new()
		smoke.out_dir = smoke_dir
		smoke.dock = chat_dock
		add_child(smoke)

	# 2c. Demo benchmark: yalnız `-- --ai-sidebar-bench=<klasör>` ile açılınca (tools/demo_bench.ps1).
	var bench_dir := AISidebarDemoBench.requested_out_dir()
	if not bench_dir.is_empty() and chat_dock:
		var bench := AISidebarDemoBench.new()
		bench.out_dir = bench_dir
		bench.dock = chat_dock
		add_child(bench)

	# 3. Dış ajan köprüsü (MCP): düğüm her zaman kurulur, yalnız ayar açıksa dinler. Benchmark editöründe
	# kurulmaz: kullanıcının açık editörü portu tutar, ölçülen de sidebar ajanıdır.
	if bench_dir.is_empty():
		mcp_bridge = AISidebarMcpBridgeControl.new()
		mcp_bridge.name = "GodotAIMcpBridge"
		add_child(mcp_bridge)

func _on_editor_settings_changed() -> void:
	if AISidebarTheme.use_editor_palette() and chat_dock and chat_dock.has_method("refresh_theme"):
		chat_dock.call("refresh_theme")

func _exit_tree() -> void:
	var es := EditorInterface.get_editor_settings()
	if es and es.settings_changed.is_connected(_on_editor_settings_changed):
		es.settings_changed.disconnect(_on_editor_settings_changed)
	if mcp_bridge:
		mcp_bridge.stop()
		mcp_bridge.queue_free()
		mcp_bridge = null
	if debugger_plugin:
		remove_debugger_plugin(debugger_plugin)
		debugger_plugin = null
	remove_autoload_singleton("GodotAIRuntimeBridge")
	AISidebarProjectSettingsTools.editor_plugin = null

	if chat_dock:
		AISidebarUITelemetryTools.register_sidebar_dock(null)
		remove_control_from_docks(chat_dock)
		chat_dock.queue_free()
		chat_dock = null
		print("[Godot AI Core] Eklenti devre dışı bırakıldı.")
	if agent_host:
		agent_host.queue_free()
		agent_host = null
