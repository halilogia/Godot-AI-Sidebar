@tool
extends EditorPlugin

const DOCK_SCENE_PATH: String = "res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn"

var chat_dock: Control = null

func _enter_tree() -> void:
	if ResourceLoader.exists(DOCK_SCENE_PATH):
		var dock_scene: PackedScene = load(DOCK_SCENE_PATH)
		if dock_scene:
			chat_dock = dock_scene.instantiate()
			add_control_to_dock(DOCK_SLOT_LEFT_UL, chat_dock)
			print("[Godot AI Core] Eklenti başarıyla yüklendi ve sol panele eklendi.")

func _exit_tree() -> void:
	if chat_dock:
		remove_control_from_docks(chat_dock)
		chat_dock.queue_free()
		chat_dock = null
		print("[Godot AI Core] Eklenti devre dışı bırakıldı.")
