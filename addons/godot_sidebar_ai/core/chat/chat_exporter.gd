@tool
extends RefCounted
class_name AISidebarChatExporter

## Gelişmiş Sohbet Dışa Aktarma Servisi (Chat Export 2.0) (SRP).
## Tüm konuşma geçmişini, tool çağrılarını, argümanları, diff/değişiklikleri,
## çalışma zamanı hatalarını ve telemetriyi insan ve AI için yapılandırılmış Markdown ve JSON formatında dışa aktarır.
##
## Everything Export: `export_transcript_to_markdown/json` task sınırları belirgin,
## compaction-proof transcript (AISidebarTaskTranscript) üzerinden tam döküm üretir.
## Hassas veriler (api key / bearer / secret / password / token) redact edilir.

const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")

static func _rx(s: String) -> String:
	return AISidebarTaskTranscript.redact_secrets(s)

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
		var txt = _rx(str(content_raw).strip_edges())
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
			lines.append(_rx(text_acc.strip_edges()))
		if image_count > 0:
			lines.append("")
			lines.append("*(📷 Attached %d Viewport Image/Screenshot)*" % image_count)
	elif content_raw != null:
		lines.append(_rx(str(content_raw).strip_edges()))
	else:
		lines.append("*(Empty message)*")
		
	lines.append("")
	lines.append("---")
	lines.append("")

static func _format_assistant_message(entry: Dictionary, content_raw: Variant, lines: PackedStringArray) -> void:
	lines.append("## 🤖 Godot AI")
	lines.append("")
	
	# Thinking / Reasoning varsa (gizli chain-of-thought export'a yazılmaz; yalnızca
	# modelin paylaştığı reasoning_content alanı yansıtılır)
	var thinking = entry.get("reasoning_content", entry.get("thinking", ""))
	if thinking != null and not str(thinking).strip_edges().is_empty():
		lines.append("> 💭 **Reasoning & Planning:**\n> " + _rx(str(thinking).strip_edges()).replace("\n", "\n> "))
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
					lines.append(_rx(args_formatted))
					lines.append("```")
					lines.append("")

	if content_raw != null and not str(content_raw).strip_edges().is_empty():
		lines.append(_rx(str(content_raw).strip_edges()))
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
		
		lines.append(status_badge + ((" — *" + _rx(msg) + "*") if not msg.is_empty() else ""))
		lines.append("")

		# Özel Alan Ayrıştırma: Dosya Değişiklikleri / Diff / Clarification
		if parsed_data.has("data") and parsed_data["data"] is Dictionary:
			var d = parsed_data["data"]
			if d.has("question") and d.has("user_answer"):
				lines.append("#### ❓ User Clarification:")
				lines.append("- **Question:** " + _rx(str(d["question"])))
				lines.append("- **User Answer:** " + _rx(str(d["user_answer"])))
				lines.append("")
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
		lines.append(_rx(JSON.stringify(parsed_data, "  ")))
		lines.append("```")
	else:
		lines.append("```text")
		lines.append(_rx(content_str))
		lines.append("```")
		
	lines.append("")
	lines.append("---")
	lines.append("")

static func _format_system_message(entry: Dictionary, content_raw: Variant, lines: PackedStringArray) -> void:
	lines.append("## 💻 System")
	lines.append("")
	if content_raw != null:
		lines.append(_rx(str(content_raw).strip_edges()))
	lines.append("")
	lines.append("---")
	lines.append("")

## Recursive hassas-veri redaction (Dictionary/Array/String yürüyüşü).
## JSON export history/metadata/tasks alanları ham veri taşıyabilir; nested
## secret'lar (or. {"auth": {"api_key": "sk-..."}}) burada temizlenir.
static func redact_recursive(v: Variant) -> Variant:
	if v is String:
		return _rx(str(v))
	if v is Array:
		var out: Array = []
		for item in (v as Array):
			out.append(redact_recursive(item))
		return out
	if v is Dictionary:
		var out_d: Dictionary = {}
		for k in (v as Dictionary).keys():
			var kv = (v as Dictionary)[k]
			# Hassas anahtar + skaler değer → tamamını maskele; container ise
			# içine in (nested secret yine yakalanır, güvenli alanlar korunur).
			if _is_sensitive_key(str(k)) and not (kv is Dictionary) and not (kv is Array):
				out_d[k] = "[REDACTED]"
			else:
				out_d[k] = redact_recursive(kv)
		return out_d
	return v

static func _is_sensitive_key(k: String) -> bool:
	var lk = k.strip_edges().to_lower()
	var sensitive = [
		"api_key", "apikey", "api-key", "bearer", "authorization",
		"secret", "client_secret", "password", "passwd", "pwd",
		"token", "access_token", "refresh_token", "auth_token", "id_token",
		"credentials", "credential", "auth", "auth_header", "session_token", "private_key"
	]
	return lk in sensitive

## Yapılandırılmış tam JSON export formatı
static func export_to_json(history: Array, session_meta: Dictionary = {}) -> String:
	var export_dict: Dictionary = {
		"export_version": "2.0",
		"format": "godot_ai_chat_export",
		"exported_at": Time.get_datetime_string_from_system(),
		"metadata": redact_recursive(session_meta),
		"total_messages": history.size(),
		"messages": redact_recursive(history)
	}
	return JSON.stringify(export_dict, "  ")

## Everything Export (Markdown): task sınırları belirgin tam transcript.
## tasks: AISidebarTaskTranscript.to_data() dizisi; history: working-memory mesajları.
static func export_transcript_to_markdown(tasks: Array, history: Array = [], session_meta: Dictionary = {}) -> String:
	var lines: PackedStringArray = []
	lines.append("# 🤖 Godot AI Chat Export")
	lines.append("")
	lines.append("- **Export Date:** " + Time.get_datetime_string_from_system())
	if not session_meta.is_empty():
		if session_meta.has("model"):
			lines.append("- **Model:** `" + _rx(str(session_meta["model"])) + "`")
		if session_meta.has("elapsed_s"):
			lines.append("- **Total Duration:** " + str(session_meta["elapsed_s"]) + "s")
	lines.append("- **Total Tasks:** " + str(tasks.size() if tasks != null else 0))
	lines.append("- **Working-Memory Messages:** " + str(history.size() if history != null else 0))
	lines.append("")
	lines.append("---")
	lines.append("")

	if tasks != null:
		var idx = 0
		for task in tasks:
			if task is Dictionary:
				idx += 1
				_append_task_section(task, idx, lines)

	if history != null and not history.is_empty():
		lines.append("## 🗂️ Session Message History (working memory)")
		lines.append("")
		lines.append("_Compaction sonrası özet içerebilir; tam kayıt için yukarıdaki Task bölümlerine bakın._")
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
						lines.append(_rx(str(content_raw).strip_edges()))
					lines.append("")
					lines.append("---")
					lines.append("")

	if not session_meta.is_empty() and session_meta.has("telemetry"):
		var tel = session_meta["telemetry"]
		if tel is Dictionary and not tel.is_empty():
			lines.append("## 📊 Session Telemetry")
			lines.append("")
			for k in tel.keys():
				lines.append("- **%s:** %s" % [str(k).replace("_", " ").capitalize(), _rx(str(tel[k]))])
			lines.append("")
			lines.append("---")
			lines.append("")

	return "\n".join(lines)

## Tek task Markdown exportu (Copy Current Task kaynağı).
static func export_single_task_to_markdown(task: Dictionary) -> String:
	if task == null or task.is_empty():
		return ""
	var lines: PackedStringArray = []
	lines.append("# 📋 Task Export — " + _rx(str(task.get("display_prompt", task.get("prompt", "(untitled)"))).strip_edges().left(100)))
	lines.append("")
	lines.append("- **Export Date:** " + Time.get_datetime_string_from_system())
	lines.append("")
	_append_task_section(task, maxi(1, int(task.get("seq", 1))), lines)
	return "\n".join(lines)

## Task içindeki son checklist snapshot'ını bulur (yoksa boş sözlük).
static func latest_checklist_snapshot(task: Dictionary) -> Dictionary:
	var evs = task.get("events", [])
	if evs == null or not (evs is Array):
		return {}
	var latest = {}
	for e in evs:
		if e is Dictionary and str((e as Dictionary).get("t", "")) == "checklist_snapshot":
			var d = (e as Dictionary).get("data", {})
			if d is Dictionary:
				latest = d
	return latest

## Everything Export (JSON): Markdown ile aynı complete transcript.
## Hassas değerler recursive redaction ile temizlenir (ham history/metadata dahil).
static func export_transcript_to_json(tasks: Array, history: Array = [], session_meta: Dictionary = {}) -> String:
	var export_dict: Dictionary = {
		"export_version": "3.0",
		"format": "godot_ai_transcript_export",
		"exported_at": Time.get_datetime_string_from_system(),
		"metadata": redact_recursive(session_meta),
		"total_tasks": tasks.size() if tasks != null else 0,
		"tasks": redact_recursive(tasks if tasks != null else []),
		"total_messages": history.size() if history != null else 0,
		"messages": redact_recursive(history if history != null else [])
	}
	return JSON.stringify(export_dict, "  ")

static func _append_task_section(task: Dictionary, idx: int, lines: PackedStringArray) -> void:
	var prompt = _rx(str(task.get("display_prompt", task.get("prompt", "(untitled)"))).strip_edges())
	var status = str(task.get("status", "unknown"))
	lines.append("## Task %d — %s `%s`" % [idx, prompt.left(80), status])
	lines.append("")
	lines.append("- **Started:** " + str(task.get("started_at", "")))
	if not str(task.get("ended_at", "")).is_empty():
		lines.append("- **Ended:** " + str(task.get("ended_at", "")))
	var stop_reason = _rx(str(task.get("stop_reason", "")).strip_edges())
	if not stop_reason.is_empty():
		lines.append("- **Stop reason:** " + stop_reason)
	lines.append("")

	var evs = task.get("events", [])
	if evs == null or not (evs is Array):
		evs = []
	var buckets = {
		"user": [], "assistant": [], "clarification": [], "plan": [],
		"tool_call": [], "tool_result": [], "verification": [],
		"runtime": [], "activity": [], "system": []
	}
	for e in evs:
		if e == null or not (e is Dictionary):
			continue
		_append_transcript_event(e, buckets)

	_append_event_bucket(lines, "### User", buckets["user"])
	_append_event_bucket(lines, "### Assistant", buckets["assistant"])
	_append_event_bucket(lines, "### Clarification", buckets["clarification"])
	_append_event_bucket(lines, "### Plan", buckets["plan"])
	_append_event_bucket(lines, "### Tool Calls", buckets["tool_call"])
	_append_event_bucket(lines, "### Tool Results", buckets["tool_result"])
	_append_event_bucket(lines, "### Activity", buckets["activity"])
	_append_event_bucket(lines, "### Verification", buckets["verification"])
	_append_event_bucket(lines, "### Runtime", buckets["runtime"])
	_append_checklist_section(lines, latest_checklist_snapshot(task))
	_append_event_bucket(lines, "### System Notes", buckets["system"])

	var metrics = task.get("metrics", {})
	if metrics is Dictionary and not metrics.is_empty():
		lines.append("### Completion")
		lines.append("")
		var succ = bool(metrics.get("success", status == "completed"))
		lines.append("- **Result:** " + ("✅ Success" if succ else "❌ Failed"))
		for k in ["steps_summary", "tool_calls", "file_ops", "elapsed_seconds", "llm_time_s", "tool_time_s", "research_time_s", "research_overhead_ratio", "read_ops", "search_ops", "write_ops", "failed_tools", "retry_count", "limit_hit", "files_read_count", "files_written_count"]:
			if metrics.has(k):
				lines.append("- **%s:** %s" % [str(k).replace("_", " ").capitalize(), _rx(str(metrics[k]))])
		lines.append("")
	elif status != "running":
		lines.append("### Completion")
		lines.append("")
		lines.append("- **Result:** " + ("✅ Success" if status == "completed" else "❌ " + status.capitalize()))
		lines.append("")

	lines.append("---")
	lines.append("")

static func _append_transcript_event(e: Dictionary, buckets: Dictionary) -> void:
	var t = str(e.get("t", ""))
	var d = e.get("data", {})
	if d == null or not (d is Dictionary):
		d = {}
	var ts = str(e.get("ts", ""))
	match t:
		"user":
			var txt = _rx(str(d.get("text", "")))
			if txt.begins_with("PLANLAMA MODU (SISTEM TALIMATI)"):
				(buckets["system"] as Array).append("<details><summary>Planning directive (internal)</summary>\n\n" + txt + "\n</details>")
			elif txt.begins_with("SİSTEM BİLGİSİ:"):
				(buckets["system"] as Array).append(txt)
			elif txt.begins_with("⚠️"):
				(buckets["runtime"] as Array).append(txt)
			else:
				(buckets["user"] as Array).append(txt)
		"assistant":
			var a_txt = _rx(str(d.get("text", "")))
			if not a_txt.strip_edges().is_empty():
				(buckets["assistant"] as Array).append(a_txt)
		"tool_call":
			var calls = d.get("calls", [])
			var parts: PackedStringArray = []
			var arg_blocks: PackedStringArray = []
			if calls is Array:
				for c in calls:
					if c is Dictionary:
						parts.append("`" + str(c.get("name", "?")) + "`")
						if str(c.get("name", "")) == "propose_plan" and not str(c.get("args", "")).is_empty():
							_append_plan_args_to_bucket(c.get("args", ""), buckets)
						var c_args = str(c.get("args", "")).strip_edges()
						if not c_args.is_empty() and c_args != "{}":
							var aview = c_args.left(1500)
							var anote = ""
							if c_args.length() > 1500 or bool(c.get("args_truncated", false)):
								anote = "\n_[args truncated in view — full value in JSON export]_"
							arg_blocks.append("`" + str(c.get("name", "?")) + "` args:\n\n```json\n" + _rx(aview) + "\n```" + anote)
			var line = "Tool requested: " + (", ".join(parts) if parts.size() > 0 else "(unknown)")
			var extra = _rx(str(d.get("text", "")))
			if not extra.strip_edges().is_empty():
				line += " — " + extra.left(300)
			(buckets["tool_call"] as Array).append(line)
			for ab in arg_blocks:
				(buckets["tool_call"] as Array).append(ab)
		"tool_result":
			var tool = str(d.get("tool", "tool"))
			if tool == "ask_user":
				(buckets["clarification"] as Array).append("**Q:** " + _rx(str(d.get("question", ""))) + "\n\n**A:** " + _rx(str(d.get("user_answer", ""))))
			else:
				var ok = bool(d.get("success", false))
				var m = _rx(str(d.get("message", "")))
				(buckets["tool_result"] as Array).append(("✅ " if ok else "❌ ") + "`" + tool + "`" + ((" — " + m) if not m.is_empty() else ""))
				var payload = str(d.get("payload", "")).strip_edges()
				if not payload.is_empty():
					var pview = payload.left(2000)
					var pnote = ""
					if payload.length() > 2000 or bool(d.get("payload_truncated", false)):
						pnote = "\n_[payload truncated in view — full value in JSON export]_"
					(buckets["tool_result"] as Array).append("<details><summary>Payload: `" + tool + "`</summary>\n\n```json\n" + _rx(pview) + "\n```" + pnote + "\n</details>")
		"clarification_requested":
			(buckets["clarification"] as Array).append("**Q:** " + _rx(str(d.get("question", ""))) + _format_options_line(d.get("options", [])))
		"clarification_answered":
			(buckets["clarification"] as Array).append("**A:** " + _rx(str(d.get("answer", ""))))
		"plan_proposed":
			(buckets["plan"] as Array).append("Proposed: %s steps, %s files%s" % [str(d.get("steps", "?")), str(d.get("files", "?")), " — " + _rx(str(d.get("goal", ""))) if not str(d.get("goal", "")).is_empty() else ""])
		"plan_approved":
			(buckets["plan"] as Array).append("✅ Plan approved by user.")
		"plan_rejected":
			(buckets["plan"] as Array).append("❌ Plan rejected: " + _rx(str(d.get("reason", ""))))
		"tool_executing":
			(buckets["tool_call"] as Array).append("▶ `" + str(d.get("tool", "?")) + "` — " + _rx(str(d.get("title", ""))) + _format_args_line(d.get("args", "")))
		"tool_completed":
			var ok2 = bool(d.get("success", false))
			var line2 = ("✅ " if ok2 else "❌ ") + "`" + str(d.get("tool", "?")) + "` — " + _rx(str(d.get("title", "")))
			var em = _rx(str(d.get("error", "")))
			if not em.is_empty():
				line2 += "\n\nError: " + em
			(buckets["tool_result"] as Array).append(line2)
		"verification_started":
			(buckets["verification"] as Array).append("Verifying `" + str(d.get("tool", "")) + "`...")
		"verification_completed":
			var ok3 = bool(d.get("valid", false))
			(buckets["verification"] as Array).append(("✅ " if ok3 else "❌ ") + _rx(str(d.get("message", ""))))
		"runtime_observation":
			var has_err = bool(d.get("has_errors", false))
			(buckets["runtime"] as Array).append(("❌ " if has_err else "✅ ") + _rx(str(d.get("summary", ""))))
		"debugging_started":
			(buckets["runtime"] as Array).append("Auto-diagnosing: " + _rx(str(d.get("summary", ""))))
		"approval_requested":
			(buckets["system"] as Array).append("Approval requested for `" + str(d.get("tool", "")) + "`.")
		"approval_granted":
			(buckets["system"] as Array).append("✅ Approved `" + str(d.get("tool", "")) + "` by user.")
		"approval_rejected":
			(buckets["system"] as Array).append("❌ Rejected `" + str(d.get("tool", "")) + "` by user.")
		"activity":
			(buckets["activity"] as Array).append(str(d.get("icon", "•")) + " " + _rx(str(d.get("title", ""))))
		"task_started", "task_ended":
			pass
		_:
			(buckets["system"] as Array).append("[" + ts + "] " + t)

static func _append_plan_args_to_bucket(args_json: Variant, buckets: Dictionary) -> void:
	var parsed = JSON.parse_string(str(args_json))
	if parsed == null or not (parsed is Dictionary):
		return
	var goal = _rx(str(parsed.get("goal", parsed.get("title", ""))))
	if not goal.strip_edges().is_empty():
		(buckets["plan"] as Array).append("**Goal:** " + goal.left(500))
	var files = parsed.get("affected_files", parsed.get("files", []))
	if files is Array and not (files as Array).is_empty():
		var fnames: PackedStringArray = []
		for f in (files as Array):
			fnames.append("`" + str(f) + "`")
		(buckets["plan"] as Array).append("**Files:** " + ", ".join(fnames).left(500))
	var steps = parsed.get("steps", [])
	if steps is Array and not (steps as Array).is_empty():
		var slines: PackedStringArray = []
		var n = 0
		for s in (steps as Array):
			n += 1
			if s is Dictionary:
				slines.append("%d. %s" % [n, _rx(str(s.get("title", s.get("description", "")))).left(200)])
			else:
				slines.append("%d. %s" % [n, _rx(str(s)).left(200)])
		(buckets["plan"] as Array).append("**Steps:**\n" + "\n".join(slines).left(1500))

static func _format_options_line(options: Variant) -> String:
	if options is Array and not (options as Array).is_empty():
		var names: PackedStringArray = []
		for o in (options as Array):
			names.append(str(o))
		return " (options: " + ", ".join(names).left(200) + ")"
	return ""

static func _format_args_line(args_text: Variant) -> String:
	var s = str(args_text).strip_edges()
	if s.is_empty() or s == "{}":
		return ""
	return "\n\n```json\n" + _rx(s.left(800)) + "\n```"

static func _append_checklist_section(lines: PackedStringArray, snap: Dictionary) -> void:
	if snap.is_empty():
		return
	var steps = snap.get("steps", [])
	if not (steps is Array) or (steps as Array).is_empty():
		return
	lines.append("### Task Checklist")
	lines.append("")
	var icons = {"pending": "☐", "running": "▶", "completed": "✓", "failed": "✕", "skipped": "–"}
	for s in (steps as Array):
		if s is Dictionary:
			var st = str((s as Dictionary).get("state", "pending"))
			var mark = str(icons.get(st, "☐"))
			lines.append("- " + mark + " " + _rx(str((s as Dictionary).get("title", ""))).left(200))
	if bool(snap.get("finished", false)):
		var sr = _rx(str(snap.get("stop_reason", "")))
		if sr.is_empty():
			lines.append("- ✓ All tasks completed.")
		else:
			lines.append("- ✕ Stopped: " + sr)
	lines.append("")

static func _append_event_bucket(lines: PackedStringArray, header: String, items: Array) -> void:
	if items.is_empty():
		return
	lines.append(header)
	lines.append("")
	for it in items:
		lines.append(str(it))
		lines.append("")


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
