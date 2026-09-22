@tool
extends RefCounted

## Copy Current Task + Task Checklist + success classification için DETERMINISTIK testler.

const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")
const AISidebarTaskChecklist = preload("res://addons/godot_sidebar_ai/ui/components/task_checklist.gd")
const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")
const AISidebarImplementationPlan = preload("res://addons/godot_sidebar_ai/core/types/implementation_plan.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")

static func _checklist(steps: Array, goal: String = "3D Hex Grid"):
	var cl = AISidebarTaskChecklist.new()
	cl.setup(steps, goal)
	cl._ready()
	return cl

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Copy yalnızca current task'ı kopyalar (önceki task karışmaz)
	var tr1 = AISidebarTaskTranscript.new()
	tr1.begin_task("İlk görev promptu", "")
	tr1.record("assistant", {"text": "İlk cevap"})
	tr1.end_task("completed", "", {"success": true})
	tr1.begin_task("İkinci görev promptu", "")
	tr1.record("assistant", {"text": "İkinci cevap"})
	tr1.end_task("completed", "", {"success": true})
	var only2 = AISidebarChatExporter.export_single_task_to_markdown(tr1.get_current_task())
	if "İkinci görev promptu" in only2 and "İkinci cevap" in only2 and not "İlk görev promptu" in only2 and not "İlk cevap" in only2:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (copy isolates current task) failed.")

	# 2. Çalışan task varsa Copy onu getirir
	var tr2 = AISidebarTaskTranscript.new()
	tr2.begin_task("Biten görev", "")
	tr2.end_task("completed", "", {"success": true})
	tr2.begin_task("Devam eden görev", "")
	var cur2 = tr2.get_current_task()
	if str(cur2.get("display_prompt", "")) == "Devam eden görev" and str(cur2.get("status", "")) == "running":
		passed += 1
	else:
		failed += 1
		errors.append("T2 (running task preferred) failed.")

	# 3. Checklist plan step sayısıyla doğru oluşuyor
	var plan3 = AISidebarImplementationPlan.new({
		"goal": "3D Hex Grid",
		"steps": ["Create HexMetrics.gd", "Create HexCell.gd", "Create HexGrid.gd", "Create Main.tscn", "Validate GDScript"],
		"verification": ["validate_script"],
	})
	var cl3 = _checklist(plan3.steps, plan3.goal)
	if cl3.step_count() == 5 and cl3.get_states() == ["pending", "pending", "pending", "pending", "pending"]:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (checklist step count) failed.")
	cl3.queue_free()

	# 4. pending → running → completed + export checklist bölümü
	var cl4 = _checklist(["Create HexCell.gd", "Validate GDScript"])
	cl4.set_step_state(0, AISidebarTaskChecklist.STATE_RUNNING)
	var mid_ok = cl4.get_states() == ["running", "pending"]
	cl4.set_step_state(0, AISidebarTaskChecklist.STATE_COMPLETED)
	cl4.set_step_state(1, AISidebarTaskChecklist.STATE_RUNNING)
	cl4.set_step_state(1, AISidebarTaskChecklist.STATE_COMPLETED)
	var tr4 = AISidebarTaskTranscript.new()
	tr4.begin_task("Checklist export", "")
	tr4.record("checklist_snapshot", {"goal": "g", "steps": cl4.to_snapshot(), "finished": true, "stop_reason": ""})
	tr4.end_task("completed", "", {"success": true})
	var md4 = AISidebarChatExporter.export_single_task_to_markdown(tr4.get_current_task())
	if mid_ok and cl4.get_states() == ["completed", "completed"] and "### Task Checklist" in md4 and "Create HexCell.gd" in md4:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (pending->running->completed) failed.")
	cl4.queue_free()

	# 5. running → failed (hata özetiyle)
	var cl5 = _checklist(["Create HexCell.gd"])
	cl5.set_step_state(0, AISidebarTaskChecklist.STATE_RUNNING)
	cl5.set_step_state(0, AISidebarTaskChecklist.STATE_FAILED, "Parse error at line 12")
	var s5 = cl5.get_step(0)
	if s5.get("state", "") == "failed" and "Parse error" in str(s5.get("error", "")) and AISidebarTaskChecklist.state_icon("failed") == "✕":
		passed += 1
	else:
		failed += 1
		errors.append("T5 (running->failed) failed.")
	cl5.queue_free()

	# 6. Task limit stop → doğru status (stopped at 3/5 + kalan skipped)
	var cl6 = _checklist(["A", "B", "C", "D", "E"])
	cl6.set_step_state(0, AISidebarTaskChecklist.STATE_COMPLETED)
	cl6.set_step_state(1, AISidebarTaskChecklist.STATE_COMPLETED)
	cl6.set_step_state(2, AISidebarTaskChecklist.STATE_COMPLETED)
	cl6.set_step_state(3, AISidebarTaskChecklist.STATE_RUNNING)
	cl6.finish_with_stop(3, "Tool-call limit reached: 20/20")
	var h6 = cl6.get_header_text()
	if cl6.get_states() == ["completed", "completed", "completed", "failed", "skipped"] and "stopped at 3/5" in h6 and "20/20" in h6:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (limit stop status) failed: '" + h6 + "'")
	cl6.queue_free()

	# 7. Gerçek payload failure → kırmızı X (outer ok + data fail)
	var bad_payload = {
		"success": true,
		"message": "Tamamlandı.",
		"data": {"success": false, "status": 1, "error": {"code": "SCRIPT_SYNTAX_ERROR", "message": "Script sözdizimi hatası içeriyor."}}
	}
	var out7 = AISidebarTaskTranscript.effective_tool_outcome(bad_payload)
	var icon7 = "✓" if bool(out7.get("success", true)) else "✕"
	if not bool(out7.get("success", true)) and icon7 == "✕" and "sözdizimi" in str(out7.get("error", "")):
		passed += 1
	else:
		failed += 1
		errors.append("T7 (payload failure -> red X) failed: " + str(out7))

	# 8. Başarılı validate → yeşil check
	var good_payload = {
		"success": true,
		"message": "✓ GDScript sözdizimi geçerli.",
		"data": {"success": true, "status": 0}
	}
	var out8 = AISidebarTaskTranscript.effective_tool_outcome(good_payload)
	if bool(out8.get("success", false)):
		passed += 1
	else:
		failed += 1
		errors.append("T8 (successful validate -> check) failed: " + str(out8))

	# 9. Checklist + ActivityGroup birlikte çalışıyor (katmanlar karışmıyor)
	var cl9 = _checklist(["Create HexCell.gd"])
	var grp9 = AISidebarActivityGroup.new(true)
	grp9._ready()
	cl9.set_step_state(0, AISidebarTaskChecklist.STATE_RUNNING)
	var aidx = grp9.add_activity("▶", "Running Updated HexCell.gd", -1, "tool")
	grp9.update_activity(aidx, "✓", "Updated HexCell.gd", 100, "result")
	cl9.set_step_state(0, AISidebarTaskChecklist.STATE_COMPLETED)
	if cl9.get_states() == ["completed"] and grp9.get_item_count() == 1 and str(grp9.get_item(0).get("icon", "")) == "✓":
		passed += 1
	else:
		failed += 1
		errors.append("T9 (checklist+activity coexistence) failed.")
	cl9.queue_free()
	grp9.queue_free()

	# 10. Existing Everything Export davranışları bozulmuyor
	var tr10 = AISidebarTaskTranscript.new()
	tr10.begin_task("Export görevi", "")
	tr10.record("clarification_requested", {"question": "2D mi?", "options": [], "id": "c"})
	tr10.record("tool_completed", {"tool": "read_script", "title": "Read script", "success": true, "error": ""})
	tr10.end_task("completed", "", {"success": true})
	var md10 = AISidebarChatExporter.export_transcript_to_markdown(tr10.to_data(), [], {})
	var js10 = JSON.parse_string(AISidebarChatExporter.export_transcript_to_json(tr10.to_data(), [], {}))
	if "## Task 1" in md10 and "### Clarification" in md10 and "2D mi?" in md10 and js10 is Dictionary and str(js10.get("export_version", "")) == "3.0":
		passed += 1
	else:
		failed += 1
		errors.append("T10 (export intact) failed.")

	# 11. Plan step başlıkları checklist'e aynen yansıyor
	var plan11 = AISidebarImplementationPlan.new({
		"goal": "Hex",
		"steps": ["Create HexMetrics.gd", "Validate GDScript"],
		"verification": ["validate_script"],
	})
	var cl11 = _checklist(plan11.steps, plan11.goal)
	if cl11.get_step(0).get("title", "") == "Create HexMetrics.gd" and cl11.get_step(1).get("title", "") == "Validate GDScript" and cl11.goal == "Hex":
		passed += 1
	else:
		failed += 1
		errors.append("T11 (plan titles mapping) failed.")
	cl11.queue_free()

	return {"name": "CopyTaskChecklistTests", "passed": passed, "failed": failed, "errors": errors}
