@tool
extends RefCounted
class_name AISidebarChatExporter

## Sohbet Dışa Aktarma Servisi (Chat Export Service) (SRP).
## Tüm konuşma akışını temiz GitHub Markdown formatına dönüştürür ve panoya/dosyaya kaydeder.
## Null/Nil değerlere ve karmaşık tool payload'larına karşı tam güvenlidir.

static func export_to_markdown(history: Array) -> String:
	var lines: PackedStringArray = []
	lines.append("# 🤖 Godot AI Chat Export")
	lines.append("**Date:** " + Time.get_datetime_string_from_system())
	lines.append("\n---\n")
	
	for entry in history:
		if entry == null or not (entry is Dictionary):
			continue
			
		var role = str(entry.get("role", "assistant"))
		var content_raw = entry.get("content")
		var content_str = str(content_raw) if content_raw != null else ""
		
		var author = "### 👤 User"
		match role:
			"user":
				author = "### 👤 User"
			"assistant":
				author = "### 🤖 Godot AI"
			"tool":
				var tool_name = str(entry.get("name", "tool"))
				author = "### ⚙️ Tool Result (`" + tool_name + "`)"
			"system":
				author = "### 💻 System"
			_:
				author = "### 💬 " + role.capitalize()
				
		lines.append(author)
		
		# Tool call payload varsa (Assistant tool çağırdığında)
		if entry.has("tool_calls") and entry["tool_calls"] is Array:
			for tc in entry["tool_calls"]:
				if tc is Dictionary:
					var fn = tc.get("function", {})
					var fn_name = str(fn.get("name", "unknown_tool"))
					var fn_args = str(fn.get("arguments", "{}"))
					lines.append("> **⚡ Tool Executed:** `" + fn_name + "`\n```json\n" + fn_args + "\n```")
					
		if not content_str.strip_edges().is_empty():
			lines.append(content_str.strip_edges())
			
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
