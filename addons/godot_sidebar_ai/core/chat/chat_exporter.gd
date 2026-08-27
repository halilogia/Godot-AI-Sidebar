@tool
extends RefCounted
class_name AISidebarChatExporter

## Gelişmiş Sohbet Dışa Aktarma Servisi (Chat Export 2.0) (SRP).
## Tüm konuşma geçmişini, tool çağrılarını, argümanları, diff/değişiklikleri,
## çalışma zamanı hatalarını ve telemetriyi insan ve AI için yapılandırılmış Markdown ve JSON formatında dışa aktarır.

static func export_to_markdown(history: Array, session_meta: Dictionary = {}) -> String:
	var lines: PackedStringArray = []
	lines.append("# 🤖 Godot AI Chat Export")
	lines.append("")
	lines.append("- **Export Date:** " + Time.get_datetime_string_from_system())
	if not session_meta.is_empty():
		if session_meta.has("model"):
			lines.append("- **Model:** `" + str(session_meta["model"]) + "`")
		if session_meta.has("elapsed_s"):
			lines.append("- **Total Duration:** " + str(session_meta["elapsed_s"]) + "s")
	lines.append("- **Total Messages:** " + str(history.size()))
	lines.append("")
	lines.append("---")
	lines.append("")
	
	for entry in history:
		if entry == null or not (entry is Dictionary):
			continue
			
		var role = str(entry.get("role", "assistant"))
		var content_raw = entry.get("content")
		
		match role:
			"user":
				_format_user_message(entry, content_raw, lines)
			"assistant":
				_format_assistant_message(entry, content_raw, lines)
			"tool":
				_format_tool_message(entry, content_raw, lines)
			"system":
				_format_system_message(entry, content_raw, lines)
			_:
				lines.append("## 💬 " + role.capitalize())
				lines.append("")
				if content_raw != null:
					lines.append(str(content_raw).strip_edges())
				lines.append("")
				lines.append("---")
				lines.append("")
				
	# Telemetri / Özet Bölümü
	if not session_meta.is_empty() and session_meta.has("telemetry"):
		var tel = session_meta["telemetry"]
		if tel is Dictionary and not tel.is_empty():
			lines.append("## 📊 Session Telemetry")
			lines.append("")
			for k in tel.keys():
				lines.append("- **%s:** %s" % [str(k).replace("_", " ").capitalize(), str(tel[k])])
			lines.append("")
			lines.append("---")
			lines.append("")
			
	return "\n".join(lines)

static func _format_user_message(entry: Dictionary, content_raw: Variant, lines: PackedStringArray) -> void:
	lines.append("## 👤 User")
	lines.append("")
	
	if content_raw is String:
		var txt = str(content_raw).strip_edges()
		if txt.begins_with("[DİNAMİK EDİTÖR ZEMİNLEMESİ]"):
			# Editör zeminleme promptu
			lines.append("<details><summary>📌 <i>Editor Grounding Context</i></summary>\n\n```text\n" + txt + "\n```\n</details>")
		else:
			lines.append(txt)
	elif content_raw is Array:
		# Multimodal içerik parçaları
		var text_acc = ""
		var image_count = 0
		for part in content_raw:
			if part is Dictionary:
				if part.get("type", "") == "text":
					text_acc += str(part.get("text", "")) + "\n"
				elif part.get("type", "") == "image_url":
					image_count += 1
		if not text_acc.strip_edges().is_empty():
			lines.append(text_acc.strip_edges())
		if image_count > 0:
			lines.append("")
			lines.append("*(📷 Attached %d Viewport Image/Screenshot)*" % image_count)
	elif content_raw != null:
		lines.append(str(content_raw).strip_edges())
	else:
		lines.append("*(Empty message)*")
		
	lines.append("")
	lines.append("---")
	lines.append("")

static func _format_assistant_message(entry: Dictionary, content_raw: Variant, lines: PackedStringArray) -> void:
	lines.append("## 🤖 Godot AI")
	lines.append("")
	
	# Thinking / Reasoning varsa
	var thinking = entry.get("reasoning_content", entry.get("thinking", ""))
	if thinking != null and not str(thinking).strip_edges().is_empty():
		lines.append("> 💭 **Reasoning & Planning:**\n> " + str(thinking).strip_edges().replace("\n", "\n> "))
		lines.append("")
		
	# Tool çağrıları varsa
	if entry.has("tool_calls") and entry["tool_calls"] is Array:
		var tc_arr = entry["tool_calls"]
		if tc_arr.size() > 0:
			lines.append("### ⚡ Tool Calls (%d)" % tc_arr.size())
			lines.append("")
			for tc in tc_arr:
				if tc is Dictionary:
					var tc_id = tc.get("id", "")
					var fn = tc.get("function", {})
					var fn_name = str(fn.get("name", tc.get("name", "unknown_tool")))
					var fn_args_raw = fn.get("arguments", tc.get("arguments", "{}"))
					
					var args_formatted = "{}"
					if fn_args_raw is Dictionary:
						args_formatted = JSON.stringify(fn_args_raw, "  ")
					elif fn_args_raw is String:
						var parsed_args = JSON.parse_string(fn_args_raw)
						if parsed_args != null:
							args_formatted = JSON.stringify(parsed_args, "  ")
						else:
							args_formatted = fn_args_raw
							
					lines.append("#### ⚡ Tool Executed: `" + fn_name + "`" + (" `(ID: " + tc_id + ")`" if not tc_id.is_empty() else ""))
					lines.append("**Arguments:**")
					lines.append("```json")
					lines.append(args_formatted)
					lines.append("```")
					lines.append("")
					
	if content_raw != null and not str(content_raw).strip_edges().is_empty():
		lines.append(str(content_raw).strip_edges())
	elif not entry.has("tool_calls") or (entry["tool_calls"] is Array and entry["tool_calls"].is_empty()):
		lines.append("*(Completed without text)*")
		
	lines.append("")
	lines.append("---")
	lines.append("")

static func _format_tool_message(entry: Dictionary, content_raw: Variant, lines: PackedStringArray) -> void:
	var tool_name = str(entry.get("name", "tool"))
	var tc_id = str(entry.get("tool_call_id", ""))
	
	lines.append("### ⚙️ Tool Result: `" + tool_name + "`" + (" `(ID: " + tc_id + ")`" if not tc_id.is_empty() else ""))
	lines.append("")
	
	var content_str = str(content_raw) if content_raw != null else "{}"
	var parsed_data = JSON.parse_string(content_str)
	
	if parsed_data is Dictionary:
		var is_success = parsed_data.get("success", true)
		var status_badge = "✅ **Status:** Success" if is_success else "❌ **Status:** Failed"
		var msg = parsed_data.get("message", "")
		
		lines.append(status_badge + ((" — *" + msg + "*") if not msg.is_empty() else ""))
		lines.append("")
		
		# Özel Alan Ayrıştırma: Dosya Değişiklikleri / Diff
		if parsed_data.has("data") and parsed_data["data"] is Dictionary:
			var d = parsed_data["data"]
			if d.has("path") or d.has("file_path"):
				var f_path = d.get("path", d.get("file_path", ""))
				lines.append("#### 📝 File Target: `" + str(f_path) + "`")
			if d.has("viewport_type") or d.get("has_vision_data", false):
				lines.append("#### 📷 Viewport Snapshot: `%s` (%sx%s)" % [str(d.get("path", "viewport.png")), str(d.get("width", 0)), str(d.get("height", 0))])
			if d.has("errors") and d["errors"] is Array and d["errors"].size() > 0:
				lines.append("#### ⚠️ Runtime Diagnostic Errors:")
				for err in d["errors"]:
					if err is Dictionary:
						lines.append("- `%s:%s`: %s" % [str(err.get("file", "")), str(err.get("line", 0)), str(err.get("message", ""))])
				lines.append("")
				
		lines.append("**Raw Result Data:**")
		lines.append("```json")
		lines.append(JSON.stringify(parsed_data, "  "))
		lines.append("```")
	else:
		lines.append("```text")
		lines.append(content_str)
		lines.append("```")
		
	lines.append("")
	lines.append("---")
	lines.append("")

static func _format_system_message(entry: Dictionary, content_raw: Variant, lines: PackedStringArray) -> void:
	lines.append("## 💻 System")
	lines.append("")
	if content_raw != null:
		lines.append(str(content_raw).strip_edges())
	lines.append("")
	lines.append("---")
	lines.append("")

## Yapılandırılmış tam JSON export formatı
static func export_to_json(history: Array, session_meta: Dictionary = {}) -> String:
	var export_dict: Dictionary = {
		"export_version": "2.0",
		"format": "godot_ai_chat_export",
		"exported_at": Time.get_datetime_string_from_system(),
		"metadata": session_meta,
		"total_messages": history.size(),
		"messages": history
	}
	return JSON.stringify(export_dict, "  ")

static func save_to_file(content_text: String, extension: String = "md") -> Dictionary:
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var ext = extension.trim_prefix(".")
	var path = "res://chat_export_" + timestamp + "." + ext
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(content_text)
		f.close()
		if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_resource_filesystem"):
			EditorInterface.get_resource_filesystem().scan()
		return {"success": true, "path": path}
	return {"success": false, "error": "Dosya oluşturulamadı: " + path}
