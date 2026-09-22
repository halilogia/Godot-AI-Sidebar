@tool
extends EditorPlugin

const DOCK_SCENE_PATH: String = "res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn"
const AISidebarUITelemetryTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/ui_telemetry_tools.gd")
const AISidebarDebuggerPlugin = preload("res://addons/godot_sidebar_ai/core/runtime/debugger_plugin.gd")

var chat_dock: Control = null
var debugger_plugin: AISidebarDebuggerPlugin = null

func _enter_tree() -> void:
	# 1. Hata Ayıklayıcı Eklentisi & Runtime Bridge
	debugger_plugin = AISidebarDebuggerPlugin.new()
	add_debugger_plugin(debugger_plugin)
	add_autoload_singleton("GodotAIRuntimeBridge", "res://addons/godot_sidebar_ai/core/runtime/runtime_bridge.gd")
	
	# 2. Sidebar Dock
	if ResourceLoader.exists(DOCK_SCENE_PATH):
		var dock_scene: PackedScene = load(DOCK_SCENE_PATH)
		if dock_scene:
			chat_dock = dock_scene.instantiate()
			chat_dock.name = "GodotAISidebar"
			add_control_to_dock(DOCK_SLOT_RIGHT_UL, chat_dock)
			AISidebarUITelemetryTools.register_sidebar_dock(chat_dock)
			print("[Godot AI Core] Eklenti başarıyla yüklendi (Sağ Dock).")

func _exit_tree() -> void:
	if debugger_plugin:
		remove_debugger_plugin(debugger_plugin)
		debugger_plugin = null
	remove_autoload_singleton("GodotAIRuntimeBridge")
	
	if chat_dock:
		AISidebarUITelemetryTools.register_sidebar_dock(null)
		remove_control_from_docks(chat_dock)
		chat_dock.queue_free()
		chat_dock = null
		print("[Godot AI Core] Eklenti devre dışı bırakıldı.")
