@tool
extends RefCounted

## Copy Chat (full-chat kronolojik transcript) için DETERMINISTIK testler.

const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")

static func _three_tasks() -> Array:
	var tr = AISidebarTaskTranscript.new()
	tr.begin_task("Birinci görev alfa", "")
	tr.mark_step(1)
	tr.record("assistant", {"text": "Alfa cevabı"})
	tr.record("tool_completed", {"tool": "read_script", "title": "Read a", "success": true, "error": ""})
	tr.end_task("completed", "", {"success": true})
	tr.begin_task("İkinci görev beta", "")
	tr.mark_step(1)
	tr.record("clarification_answered", {"answer": "Beta seçimi"})
	tr.mark_step(2)
	tr.record("tool_completed", {"tool": "write_files", "title": "Wrote b", "success": false, "error": "Disk dolu."})
	tr.end_task("failed", "Disk dolu.", {"success": false})
	tr.begin_task("Üçüncü görev gama", "")
	tr.mark_step(1)
	tr.record("assistant", {"text": "Gama cevabı"})
	tr.end_task("completed", "", {"success": true})
	return tr.to_data()

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Task 1 → Task 2 → Task 3 sırası
	var tasks = _three_tasks()
	var md = AISidebarChatExporter.export_full_chat_chronological(tasks)
	var p1 = md.find("Birinci görev alfa")
	var p2 = md.find("İkinci görev beta")
	var p3 = md.find("Üçüncü görev gama")
	if p1 > 0 and p1 < p2 and p2 < p3:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (task order) failed: %d %d %d" % [p1, p2, p3])

	# 2. Her taskın event sırası korunuyor
	var beta_q = md.find("Beta seçimi")
	var beta_tool = md.find("Wrote b")
	if beta_q > p2 and beta_q < beta_tool and beta_tool < p3:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (per-task event order) failed.")

	# 3. Son task otomatik seçilmiyor; TÜM tasklar dahil (başlıklar + içerik)
	var h1 = md.find("## Task 1")
	var h2 = md.find("## Task 2")
	var h3 = md.find("## Task 3")
	if h1 > 0 and h2 > h1 and h3 > h2 and "Alfa cevabı" in md and "Gama cevabı" in md and "Disk dolu" in md:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (all tasks included) failed.")

	# 4. Redaction korunuyor (secret task içeriğinde)
	var tr4 = AISidebarTaskTranscript.new()
	tr4.begin_task("Gizli sohbet", "")
	tr4.record("tool_executing", {"tool": "mcp", "title": "x", "args": "{\"api_key\": \"sk-12345\"}"})
	tr4.record("assistant", {"text": "Bearer abcdef123456 ile bağlan"})
	tr4.end_task("completed", "", {"success": true})
	var md4 = AISidebarChatExporter.export_full_chat_chronological(tr4.to_data())
	if not "sk-12345" in md4 and not "abcdef123456" in md4 and "[REDACTED]" in md4:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (redaction) failed.")

	# 5. Boş transcript güvenli
	var md5 = AISidebarChatExporter.export_full_chat_chronological([])
	var md5b = AISidebarChatExporter.export_full_chat_chronological([null, {}])
	if "**Total Tasks:** 0" in md5 and "Chat Transcript" in md5b:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (empty safety) failed.")

	# 6. Mevcut tek-task kronolojik export bozulmadı
	var single = AISidebarChatExporter.export_single_task_chronological(tasks[1])
	if "İkinci görev beta" in single and "Beta seçimi" in single and not "Birinci görev alfa" in single and "## Timeline" in single:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (single-task intact) failed.")

	return {"name": "CopyChatTests", "passed": passed, "failed": failed, "errors": errors}
