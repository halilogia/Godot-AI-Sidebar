@tool
extends RefCounted
class_name AISidebarChatManager

## Sohbet Oturumları Kalıcılık ve Yönetim Servisi (Chat Manager Service) (SRP).
## Tüm konuşma geçmişlerini 'user://sidebar_ai_chats' dizininde izole, güvenli JSON dosyalarında saklar.
## Asla API anahtarı veya gizli anahtar kaydetmez.

const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")
const CHAT_DIR = "user://sidebar_ai_chats"

static func ensure_storage_dir() -> void:
	if not DirAccess.dir_exists_absolute(CHAT_DIR):
		DirAccess.make_dir_recursive_absolute(CHAT_DIR)

static func list_sessions() -> Array[Dictionary]:
	ensure_storage_dir()
	var sessions: Array[Dictionary] = []
	var dir = DirAccess.open(CHAT_DIR)
	if not dir:
		return sessions
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path = CHAT_DIR + "/" + file_name
			var f = FileAccess.open(file_path, FileAccess.READ)
			if f:
				var json_str = f.get_as_text()
				f.close()
				var parsed = JSON.parse_string(json_str)
				if parsed is Dictionary and parsed.has("id"):
					var msg_count = 0
					if parsed.has("messages") and parsed["messages"] is Array:
						msg_count = parsed["messages"].size()
					sessions.append({
						"id": str(parsed.get("id", "")),
						"title": str(parsed.get("title", "Untitled Chat")),
						"created_at": str(parsed.get("created_at", "")),
						"updated_at": str(parsed.get("updated_at", "")),
						"message_count": msg_count,
						"file_path": file_path
					})
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# En yeni güncellenen en üstte olacak şekilde sırala (updated_at DESC)
	sessions.sort_custom(func(a, b):
		return a.get("updated_at", "") > b.get("updated_at", "")
	)
	return sessions

static func save_session(session: AISidebarChatSession) -> bool:
	if session == null or session.id.is_empty():
		return false
	ensure_storage_dir()
	session.update_timestamp()
	session.auto_title_from_first_message()
	
	var file_path = CHAT_DIR + "/" + session.id + ".json"
	var f = FileAccess.open(file_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(session.to_dict(), "  "))
		f.close()
		return true
	return false

static func load_session(session_id: String) -> AISidebarChatSession:
	if session_id.is_empty():
		return null
	ensure_storage_dir()
	var file_path = CHAT_DIR + "/" + session_id + ".json"
	if not FileAccess.file_exists(file_path):
		return null
		
	var f = FileAccess.open(file_path, FileAccess.READ)
	if not f:
		return null
		
	var json_str = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(json_str)
	if parsed is Dictionary:
		return AISidebarChatSession.from_dict(parsed)
	return null

static func delete_session(session_id: String) -> bool:
	if session_id.is_empty():
		return false
	ensure_storage_dir()
	var file_path = CHAT_DIR + "/" + session_id + ".json"
	if FileAccess.file_exists(file_path):
		return DirAccess.remove_absolute(file_path) == OK
	return false

static func rename_session(session_id: String, new_title: String) -> bool:
	var sess = load_session(session_id)
	if sess:
		sess.title = new_title.strip_edges()
		return save_session(sess)
	return false

static func clear_all_sessions() -> bool:
	ensure_storage_dir()
	var dir = DirAccess.open(CHAT_DIR)
	if not dir:
		return false
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			DirAccess.remove_absolute(CHAT_DIR + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return true
