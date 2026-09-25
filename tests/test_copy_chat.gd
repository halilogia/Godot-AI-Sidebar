@tool
extends RefCounted

## Copy Chat (full-chat kronolojik transcript) için DETERMINISTIK testler.

const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")
const AISidebarTelemetryCard = preload("res://addons/godot_sidebar_ai/ui/components/telemetry_card.gd")

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

	# 7. Per-task copy: ikinci task birincinin içeriğini taşımaz
	var tr7 = AISidebarTaskTranscript.new()
	tr7.begin_task("Alfa özel içerik", "")
	tr7.record("assistant", {"text": "Alfa cevabı"})
	tr7.end_task("completed", "", {"success": true})
	tr7.begin_task("Beta özel içerik", "")
	tr7.record("assistant", {"text": "Beta cevabı"})
	tr7.end_task("completed", "", {"success": true})
	var all7 = tr7.to_data()
	var beta_task = AISidebarTaskTranscript.new()
	beta_task.load_data(all7)
	var second_id = str(all7[1].get("id", ""))
	var copy7 = AISidebarChatExporter.export_single_task_chronological(beta_task.get_task_by_id(second_id))
	if "Beta özel içerik" in copy7 and "Beta cevabı" in copy7 and not "Alfa özel içerik" in copy7 and not "Alfa cevabı" in copy7 and "## Timeline" in copy7:
		passed += 1
	else:
		failed += 1
		errors.append("T7 (second-task isolation) failed.")

	# 8. Eski (birinci) task kopyalanabiliyor
	var first_id = str(all7[0].get("id", ""))
	var copy8 = AISidebarChatExporter.export_single_task_chronological(beta_task.get_task_by_id(first_id))
	if "Alfa özel içerik" in copy8 and "Alfa cevabı" in copy8 and not "Beta özel içerik" in copy8:
		passed += 1
	else:
		failed += 1
		errors.append("T8 (old task copy) failed.")

	# 9. Kopyalanan task içi sıra kronolojik
	var tr9 = AISidebarTaskTranscript.new()
	tr9.begin_task("Sıralı görev", "")
	tr9.mark_step(1)
	tr9.record("assistant", {"text": "Önce bu"})
	tr9.mark_step(2)
	tr9.record("tool_completed", {"tool": "read_script", "title": "Sonra bu", "success": true, "error": ""})
	tr9.end_task("completed", "", {"success": true})
	var tid9 = str(tr9.to_data()[0].get("id", ""))
	var copy9 = AISidebarChatExporter.export_single_task_chronological(tr9.get_task_by_id(tid9))
	if copy9.find("Önce bu") < copy9.find("Sonra bu") and "[S1]" in copy9 and "[S2]" in copy9:
		passed += 1
	else:
		failed += 1
		errors.append("T9 (copied order) failed.")

	# 10. task_resumed içeren task kopyalanıyor (pause/resume geçmişi korunur)
	var tr10 = AISidebarTaskTranscript.new()
	tr10.begin_task("Devamlı görev", "")
	tr10.end_task("cancelled", "Durduruldu.")
	tr10.reopen_task(str(tr10.to_data()[0].get("id", "")))
	tr10.record("assistant", {"text": "Devam cevabı"})
	tr10.end_task("completed", "", {"success": true})
	var tid10 = str(tr10.to_data()[0].get("id", ""))
	var copy10 = AISidebarChatExporter.export_single_task_chronological(tr10.get_task_by_id(tid10))
	if "Task resumed" in copy10 and "Devam cevabı" in copy10:
		passed += 1
	else:
		failed += 1
		errors.append("T10 (resumed copy) failed.")

	# 12. Telemetry kartı Copy butonu task_id yayar; boşken gizli
	var card12 = AISidebarTelemetryCard.new({"success": true, "elapsed_seconds": 1.0})
	card12.task_id = "task_abc"
	card12._ready()
	var got12: Array = []
	card12.copy_task_requested.connect(func(tid): got12.append(tid))
	card12._copy_btn.pressed.emit()
	var card12b = AISidebarTelemetryCard.new({})
	card12b._ready()
	if got12 == ["task_abc"] and not card12b._copy_btn.visible:
		passed += 1
	else:
		failed += 1
		errors.append("T12 (card copy button) failed.")
	card12.queue_free()
	card12b.queue_free()

	return {"name": "CopyChatTests", "passed": passed, "failed": failed, "errors": errors}
