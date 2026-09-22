@tool
extends RefCounted

## Benchmark hazırlık denetimi: gerçek task sonrası transcript'in post-mortem
## analiz için yeterli ham kanıt taşıyıp taşımadığı (9 soru + 6-alan formatı).
## "Necessary/Recovery/Redundant" sınıflandırması YOK; yalnızca kanıt zinciri.

const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarTaskChecklist = preload("res://addons/godot_sidebar_ai/ui/components/task_checklist.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")

## Gerçekçi mini-task: S5 read → S5 write fail → S6 validate fail → S6 fix → S7 validate ok.
## p_end_task=false ise task açık bırakılır (limit/fail senaryoları için).
static func _build_recovery_transcript(ctx, p_end_task: bool = true) -> void:
	ctx.begin_task("Hexagon oluştur", "")
	ctx.get_transcript().mark_step(1)
	ctx.get_transcript().record("clarification_requested", {"question": "2D mi 3D mi?", "options": ["2D", "3D"], "id": "c1"})
	ctx.get_transcript().record("clarification_answered", {"answer": "3D yap"})
	ctx.get_transcript().mark_step(2)
	ctx.add_assistant_tool_call_message("Önce dosyayı okuyorum.", [{"name": "read_script", "arguments": {"file_path": "res://HexCell.gd"}}], "Dosya içeriğini görmem lazım.")
	ctx.get_transcript().mark_step(5)
	ctx.add_assistant_tool_call_message("", [{"name": "create_or_update_script", "arguments": {"file_path": "res://HexCell.gd", "content": "extends Node3D"}}])
	ctx.add_tool_result_message("cw1", "create_or_update_script", {"success": false, "message": "Yazma hatası", "data": {}})
	ctx.get_transcript().mark_step(6)
	ctx.add_assistant_tool_call_message("", [{"name": "validate_script", "arguments": {"file_path": "res://HexCell.gd"}}])
	ctx.add_tool_result_message("v1", "validate_script", {"success": true, "message": "Tamamlandı.", "data": {"success": false, "status": 1, "error": {"code": "SCRIPT_SYNTAX_ERROR", "message": "Unexpected indent."}}})
	ctx.get_transcript().record("verification_completed", {"tool": "validate_script", "valid": false, "message": "Unexpected indent."})
	ctx.add_assistant_tool_call_message("", [{"name": "replace_file_content", "arguments": {"file_path": "res://HexCell.gd", "old": "\t\t", "new": "\t"}}])
	ctx.add_tool_result_message("f1", "replace_file_content", {"success": true, "message": "Fixed.", "data": {"file_path": "res://HexCell.gd"}})
	ctx.get_transcript().mark_step(7)
	ctx.add_assistant_tool_call_message("", [{"name": "validate_script", "arguments": {"file_path": "res://HexCell.gd"}}])
	ctx.add_tool_result_message("v2", "validate_script", {"success": true, "message": "Geçerli.", "data": {"success": true, "status": 0}})
	if p_end_task:
		ctx.end_task("completed", "", {"success": true, "used_steps": 7, "max_steps": 20})

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# Q1. Tool NEDEN çağrıldı? (thinking snippet kanıtı)
	var ctx1 = AISidebarAgentContext.new()
	ctx1.begin_task("t", "")
	ctx1.add_assistant_tool_call_message("", [{"name": "read_script", "arguments": {}}], "Dosya içeriğini görmem lazım çünkü tip hatası var.")
	var ev1 = ctx1.get_transcript().to_data()[0]["events"]
	var thought_ok = false
	for e in ev1:
		if e is Dictionary and str(e.get("t", "")) == "tool_call" and "tip hatası" in str((e.get("data", {}) as Dictionary).get("thinking", "")):
			thought_ok = true
	if thought_ok:
		passed += 1
	else:
		failed += 1
		errors.append("Q1 (why: thinking evidence) failed.")

	# Q2+Q5. Failure sonrası çağrı + HANGİ STEP'te validation failure (mutlak step no)
	var ctx2 = AISidebarAgentContext.new()
	_build_recovery_transcript(ctx2)
	var task2 = ctx2.get_transcript().to_data()[0]
	var v_fail_step = -1
	var fix_after_fail = false
	var seen_fail = false
	for e in task2["events"]:
		if not (e is Dictionary):
			continue
		var d = e.get("data", {})
		if not (d is Dictionary):
			continue
		if str(e.get("t", "")) == "tool_result" and str(d.get("tool", "")) == "validate_script" and not bool(d.get("success", true)):
			v_fail_step = int(e.get("step", -1))
			seen_fail = true
		if seen_fail and str(e.get("t", "")) == "tool_call":
			var calls = (d as Dictionary).get("calls", [])
			if calls is Array:
				for c in calls:
					if c is Dictionary and str(c.get("name", "")) == "replace_file_content":
						fix_after_fail = true
	if v_fail_step == 6 and fix_after_fail:
		passed += 1
	else:
		failed += 1
		errors.append("Q2/Q5 (fail step + recovery order) failed: step=%d fix=%s" % [v_fail_step, str(fix_after_fail)])

	# Q3. Aynı dosyanın tekrar okunması görünüyor
	var ctx3 = AISidebarAgentContext.new()
	ctx3.begin_task("t", "")
	ctx3.add_assistant_tool_call_message("", [{"name": "read_script", "arguments": {"file_path": "res://a.gd"}}])
	ctx3.add_tool_result_message("r1", "read_script", {"success": true, "data": {}, "message": "ok"})
	ctx3.add_assistant_tool_call_message("", [{"name": "read_script", "arguments": {"file_path": "res://a.gd"}}])
	ctx3.add_tool_result_message("r2", "read_script", {"success": true, "data": {}, "message": "ok"})
	ctx3.end_task("completed", "", {"success": true})
	var reads = 0
	for e in ctx3.get_transcript().to_data()[0]["events"]:
		if e is Dictionary and str(e.get("t", "")) == "tool_call":
			for c in ((e.get("data", {}) as Dictionary).get("calls", []) as Array):
				if c is Dictionary and str(c.get("name", "")) == "read_script" and "a.gd" in str(c.get("args", "")):
					reads += 1
	if reads == 2:
		passed += 1
	else:
		failed += 1
		errors.append("Q3 (repeat reads visible) failed: %d" % reads)

	# Q4. Aynı tool'un tekrarı görünüyor
	var ctx4 = AISidebarAgentContext.new()
	ctx4.begin_task("t", "")
	for i in range(3):
		ctx4.add_assistant_tool_call_message("", [{"name": "analyze_project", "arguments": {}}])
	ctx4.end_task("failed", "Ajan aynı aracı tekrarladı.", {"success": false})
	var calls4 = 0
	for e in ctx4.get_transcript().to_data()[0]["events"]:
		if e is Dictionary and str(e.get("t", "")) == "tool_call":
			calls4 += 1
	if calls4 == 3:
		passed += 1
	else:
		failed += 1
		errors.append("Q4 (repeat tools visible) failed.")

	# Q6+Q7. Recovery sırası + limit öncesi son step'ler tam (compaction-proof)
	var ctx6 = AISidebarAgentContext.new()
	_build_recovery_transcript(ctx6, false)
	for i in range(30):
		ctx6.get_transcript().mark_step(8 + i)
		ctx6.add_user_message("Dolgu %d" % i, false, "", [])
	ctx6.end_task("failed", "Maksimum ajan adım limitine (20) ulaşıldı.", {"success": false, "used_steps": 21, "max_steps": 20, "limit_hit": true})
	var task6 = ctx6.get_transcript().to_data()[0]
	var has_vfail = false
	var has_fix = false
	var has_step_marks = true
	for e in task6["events"]:
		if not (e is Dictionary):
			continue
		if int(e.get("step", 0)) <= 0 and str(e.get("t", "")) not in ["task_started", "task_ended"]:
			has_step_marks = false
		var d = e.get("data", {})
		if d is Dictionary and str(d.get("tool", "")) == "validate_script" and not bool(d.get("success", true)):
			has_vfail = true
		if d is Dictionary and str(d.get("tool", "")) == "replace_file_content":
			has_fix = true
	if has_vfail and has_fix and has_step_marks and str(task6.get("stop_reason", "")) != "":
		passed += 1
	else:
		failed += 1
		errors.append("Q6/Q7 (recovery + limit tail) failed.")

	# Q8. Plan step ↔ tool attribution (by_tool) export ediliyor
	var cl8 = AISidebarTaskChecklist.new()
	cl8.setup(["Create HexCell.gd", "Validate GDScript"], "Hex")
	cl8._ready()
	cl8.set_step_state(0, AISidebarTaskChecklist.STATE_COMPLETED, "", "create_or_update_script")
	var tr8 = AISidebarTaskTranscript.new()
	tr8.begin_task("t", "")
	tr8.record("checklist_snapshot", {"goal": "Hex", "steps": cl8.to_snapshot(), "finished": false, "stop_reason": ""})
	tr8.end_task("completed", "", {"success": true})
	var md8 = AISidebarChatExporter.export_single_task_to_markdown(tr8.get_current_task())
	if "via `create_or_update_script`" in md8 and "### Task Checklist" in md8:
		passed += 1
	else:
		failed += 1
		errors.append("Q8 (plan-tool attribution) failed.")
	cl8.queue_free()

	# Q9 + 6-alan formatı: tool_name / args özeti / success / step / file(s) / duration
	var ctx9 = AISidebarAgentContext.new()
	_build_recovery_transcript(ctx9, false)
	ctx9.get_transcript().record("tool_completed", {"tool": "validate_script", "title": "Validated", "success": false, "error": "Unexpected indent.", "duration_ms": 120})
	ctx9.end_task("completed", "", {"success": true, "used_steps": 7, "max_steps": 20})
	var md9 = AISidebarChatExporter.export_transcript_to_markdown(ctx9.get_transcript().to_data(), [], {})
	var checks9 = [
		"validate_script" in md9,
		"HexCell.gd" in md9,
		"❌" in md9 and "✅" in md9,
		"[S6]" in md9 and "[S7]" in md9,
		"120ms" in md9,
		"Model reasoning" in md9,
	]
	var all9 = true
	for c in checks9:
		all9 = all9 and c
	if all9:
		passed += 1
	else:
		failed += 1
		errors.append("Q9 (6-field format) failed: " + str(checks9))

	return {"name": "BenchmarkReadinessTests", "passed": passed, "failed": failed, "errors": errors}
