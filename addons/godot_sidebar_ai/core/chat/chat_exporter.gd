@tool
extends RefCounted
class_name AISidebarChatExporter

## Sohbet Dışa Aktarma Servisi (Chat Export Service) (SRP).
## Tüm konuşma akışını temiz GitHub Markdown formatına dönüştürür ve panoya/dosyaya kaydeder.

static func export_to_markdown(history: Array) -> String:
	var lines: PackedStringArray = []
	lines.append("# 🤖 Godot AI Chat Export")
	lines.append("**Date:** " + Time.get_datetime_string_from_system())
	lines.append("\n---\n")
	
	for entry in history:
		var role = entry.get("role", "assistant")
		var content = entry.get("content", "")
		var author = "### 👤 User" if role == "user" else "### 🤖 Godot AI"
		
		lines.append(author)
		lines.append(content.strip_edges())
		lines.append("\n---\n")
		
	return "\n".join(lines)

static func save_to_file(markdown_text: String) -> Dictionary:
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var path = "res://chat_export_" + timestamp + ".md"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(markdown_text)
		f.close()
		if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_resource_filesystem"):
			EditorInterface.get_resource_filesystem().scan()
		return {"success": true, "path": path}
	return {"success": false, "error": "Dosya oluşturulamadı."}
