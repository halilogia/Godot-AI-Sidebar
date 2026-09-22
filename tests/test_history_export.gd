@tool
extends RefCounted

## History Chat Export: eski session yükleme + MD/JSON + sanitize + iptal güvenliği.

const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")

static func _old_session() -> AISidebarChatSession:
	var s = AISidebarChatSession.new("", "Eski Sohbet: Hexagon/3D*Kurulum?")
	s.messages = [
		{"role": "user", "content": "Hexagon oluştur"},
		{"role": "assistant", "content": "Anlaşıldı, 3D grid kuruyorum."},
		{"role": "tool", "name": "create_or_update_script", "tool_call_id": "c1", "content": "{\"success\": true, \"data\": {\"file_path\": \"res://HexCell.gd\"}, \"message\": \"ok\"}"},
	]
	s.transcript_tasks = [
		{"id": "task_1", "seq": 1, "prompt": "Hexagon oluştur", "display_prompt": "Hexagon oluştur", "started_at": "t0", "ended_at": "t1", "status": "completed", "stop_reason": "", "metrics": {"success": true}, "events": [
			{"t": "task_started", "ts": "t0", "step": 0, "data": {"prompt": "Hexagon oluştur"}},
			{"t": "user", "ts": "t0", "step": 1, "data": {"text": "Hexagon oluştur"}},
			{"t": "tool_completed", "ts": "t1", "step": 2, "data": {"tool": "create_or_update_script", "title": "Updated HexCell.gd", "success": true, "error": ""}},
			{"t": "task_ended", "ts": "t1", "step": 2, "data": {"status": "completed", "stop_reason": ""}},
		]},
		{"id": "task_2", "seq": 2, "prompt": "Işıkları ekle", "display_prompt": "Işıkları ekle", "started_at": "t2", "ended_at": "t3", "status": "failed", "stop_reason": "Timeout", "metrics": {"success": false}, "events": [
			{"t": "task_started", "ts": "t2", "step": 0, "data": {"prompt": "Işıkları ekle"}},
			{"t": "task_ended", "ts": "t3", "step": 1, "data": {"status": "failed", "stop_reason": "Timeout"}},
		]},
	]
	s.telemetry = {"tool_calls": 1}
	return s

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	AISidebarChatManager.clear_all_sessions()

	var sess = _old_session()
	AISidebarChatManager.save_session(sess)
	var loaded = AISidebarChatManager.load_session(sess.id)
	if loaded == null:
		failed += 9
		errors.append("Setup (save/load old session) failed.")
		return {"name": "HistoryExportTests", "passed": passed, "failed": failed, "errors": errors}

	# A) eski session -> Markdown (task timeline + tool içeriği)
	var md = AISidebarChatExporter.export_session_markdown(loaded)
	if "## Task 1" in md and "## Task 2" in md and "HexCell.gd" in md and "Hexagon oluştur" in md:
		passed += 1
	else:
		failed += 1
		errors.append("A (old session markdown) failed.")

	# B) eski session -> JSON (parse + alanlar)
	var js = AISidebarChatExporter.export_session_json(loaded)
	var parsed = JSON.parse_string(js)
	if parsed is Dictionary and (parsed.get("tasks", []) as Array).size() == 2 and (parsed.get("messages", []) as Array).size() == 3:
		passed += 1
	else:
		failed += 1
		errors.append("B (old session json) failed.")

	# C) transcript_tasks korunuyor (status + stop reason dahil)
	var t2 = (parsed.get("tasks", []) as Array)[1]
	if t2 is Dictionary and str(t2.get("status", "")) == "failed" and str(t2.get("stop_reason", "")) == "Timeout":
		passed += 1
	else:
		failed += 1
		errors.append("C (transcript preserved) failed.")

	# D) JSON secret redaction
	var sess_d = AISidebarChatSession.new("", "Gizli")
	sess_d.messages = [{"role": "user", "content": "{\"api_key\": \"sk-abc123\"}"}]
	var js_d = AISidebarChatExporter.export_session_json(sess_d)
	if not "sk-abc123" in js_d and "[REDACTED]" in js_d:
		passed += 1
	else:
		failed += 1
		errors.append("D (json redaction) failed.")

	# E) Markdown'da base64 blob yok
	var big_b64 = "A".repeat(500)
	var sess_e = AISidebarChatSession.new("", "Görsel")
	sess_e.messages = [{"role": "tool", "name": "take_runtime_screenshot", "tool_call_id": "c9", "content": "{\"success\": true, \"data\": {\"path\": \"user://s.png\", \"width\": 8, \"height\": 4, \"base64\": \"" + big_b64 + "\", \"has_vision_data\": true}, \"message\": \"ok\"}"}]
	var md_e = AISidebarChatExporter.export_session_markdown(sess_e)
	if not big_b64 in md_e and "📷 Screenshot" in md_e:
		passed += 1
	else:
		failed += 1
		errors.append("E (markdown squelch) failed.")

	# F) filename sanitization
	var f1 = AISidebarChatExporter.sanitize_export_filename("Eski Sohbet: Hexagon/3D*Kurulum?", "md")
	var f2 = AISidebarChatExporter.sanitize_export_filename("", "json")
	var f3 = AISidebarChatExporter.sanitize_export_filename("ok", "exe")
	var bad_chars = ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
	var has_bad = false
	for ch in bad_chars:
		if ch in f1:
			has_bad = true
	if f1 == "Eski Sohbet_ Hexagon_3D_Kurulum_.md" and f2 == "chat_export.json" and f3 == "ok.md" and not has_bad:
		passed += 1
	else:
		failed += 1
		errors.append("F (sanitize) failed: '" + f1 + "' '" + f2 + "' '" + f3 + "'")

	# G) iptal/boş güvenli: build null + dialog iptali = dosya yazılmaz, crash yok
	var built_null = AISidebarChatExporter.build_history_export(null, "md")
	var built_ok = AISidebarChatExporter.build_history_export(loaded, "md")
	if not bool(built_null.get("ok", true)) and bool(built_ok.get("ok", false)) and not str(built_ok.get("content", "")).is_empty() and str(built_ok.get("filename", "")).ends_with(".md"):
		passed += 1
	else:
		failed += 1
		errors.append("G (cancel safety) failed.")

	# H) bitmiş/failed tasklar dahil tüm session export ediliyor (aktif task şart değil)
	if "Işıkları ekle" in md and "failed" in md.to_lower():
		passed += 1
	else:
		failed += 1
		errors.append("H (inactive tasks included) failed.")

	# I) mevcut exporter davranışı (legacy mesaj formatı) bozulmadı
	if "## 👤 User" in md and "### ⚙️ Tool Result: `create_or_update_script`" in md:
		passed += 1
	else:
		failed += 1
		errors.append("I (legacy format intact) failed.")

	AISidebarChatManager.delete_session(sess.id)
	return {"name": "HistoryExportTests", "passed": passed, "failed": failed, "errors": errors}
