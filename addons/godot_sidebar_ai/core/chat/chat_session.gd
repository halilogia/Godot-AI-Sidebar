@tool
extends RefCounted
class_name AISidebarChatSession

## Tekil Sohbet Oturumu Modeli (Chat Session Model) (SRP).
## Konuşma geçmişini, başlığı, oluşturulma/güncellenme zamanlarını ve telemetriyi kapsüller.

var id: String = ""
var title: String = "New Chat"
var created_at: String = ""
var updated_at: String = ""
var messages: Array = []
var telemetry: Dictionary = {}
var metadata: Dictionary = {}

func _init(p_id: String = "", p_title: String = "New Chat") -> void:
	var now = Time.get_datetime_string_from_system()
	id = p_id if not p_id.is_empty() else "chat_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)
	title = p_title
	created_at = now
	updated_at = now

func update_timestamp() -> void:
	updated_at = Time.get_datetime_string_from_system()

func auto_title_from_first_message() -> void:
	if title != "New Chat" and not title.is_empty():
		return
	for m in messages:
		if m is Dictionary and m.get("role") == "user":
			var c = m.get("content")
			var raw_text = ""
			if c is String:
				raw_text = c.strip_edges()
			elif c is Array:
				for p in c:
					if p is Dictionary and p.get("type") == "text":
						raw_text = str(p.get("text", "")).strip_edges()
						break
			if not raw_text.is_empty():
				var first_line = raw_text.split("\n")[0].strip_edges()
				if first_line.begins_with("[DİNAMİK EDİTÖR ZEMİNLEMESİ]") or first_line.begins_with("==="):
					continue
				if first_line.length() > 35:
					title = first_line.left(35) + "..."
				else:
					title = first_line
				break

func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"created_at": created_at,
		"updated_at": updated_at,
		"messages": messages,
		"telemetry": telemetry,
		"metadata": metadata
	}

static func from_dict(d: Dictionary):
	var script_cls = load("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")
	var session = script_cls.new(str(d.get("id", "")), str(d.get("title", "New Chat")))
	session.created_at = str(d.get("created_at", Time.get_datetime_string_from_system()))
	session.updated_at = str(d.get("updated_at", Time.get_datetime_string_from_system()))
	session.messages = d.get("messages", []).duplicate(true)
	session.telemetry = d.get("telemetry", {}).duplicate(true)
	session.metadata = d.get("metadata", {}).duplicate(true)
	return session
