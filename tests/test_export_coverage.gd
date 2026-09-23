@tool
extends RefCounted

## Chat Export invariant: her export-relevant veri exportta temsil edilir.
## Bilinçli hariç: Action Summary (UI-only, tool event'lerden türetilebilir).

const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")
const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")

static func _task_with_all() -> Dictionary:
	var tr = AISidebarTaskTranscript.new()
	tr.begin_task("Kapsam görevi", "")
	tr.mark_step(2)
	tr.record("user", {"text": "Bak", "has_images": true})
	tr.record("tool_completed", {"tool": "read_script", "title": "Read a", "success": true, "error": ""})
	tr.record("task_resumed", {})
	tr.end_task("completed", "", {"success": true, "tool_time_by_tool_s": {"read_script": 1.2, "validate_script": 0.3}, "files_read": ["res://a.gd", "res://b.gd"], "files_written": [], "steps_summary": "2 / 20"})
	return tr.get_current_task()

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	var task = _task_with_all()

	# 1. task_resumed görünür (grouped + chronological)
	var md1 = AISidebarChatExporter.export_single_task_to_markdown(task)
	var md1c = AISidebarChatExporter.export_single_task_chronological(task)
	if "Task resumed" in md1 and "Task resumed" in md1c:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (task_resumed rendered) failed.")

	# 2. per-tool süreler completion'da
	if "read_script" in md1 and "1.2s" in md1:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (per-tool times) failed.")

	# 3. dosya listeleri completion'da
	if "a.gd" in md1 and "b.gd" in md1:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (file lists) failed.")

	# 4. image eki satırı var, blob yok
	if "📷 Image(s) attached" in md1:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (image suffix) failed.")

	# 5. bilinmeyen gelecek event tipi sessiz kaybolmaz (fallback görünürlüğü)
	var tr5 = AISidebarTaskTranscript.new()
	tr5.begin_task("t", "")
	tr5.record("future_event_xyz", {"info": "deneme"})
	tr5.end_task("completed", "", {"success": true})
	var md5 = AISidebarChatExporter.export_single_task_to_markdown(tr5.get_current_task())
	if "future_event_xyz" in md5:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (unknown-event fallback) failed.")

	# 6. Action Summary exportta ikinci kez modellenmiyor (bilinçli hariç)
	var md6 = AISidebarChatExporter.export_transcript_to_markdown([task], [], {})
	if not "Model ne yapıyor" in md6 and "Read a" in md6:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (no summary duplication) failed.")

	return {"name": "ExportCoverageTests", "passed": passed, "failed": failed, "errors": errors}
