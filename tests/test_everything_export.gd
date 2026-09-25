@tool
extends RefCounted

## Everything Export + transcript altyapısı için DETERMINISTIK testler.
## Transcript, context compaction sonrasında bile task geçmişini korur;
## Markdown ve JSON export aynı complete transcripti temsil eder.

const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarChatExporter = preload("res://addons/godot_sidebar_ai/core/chat/chat_exporter.gd")
const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")

static func _make_full_task(ctx) -> void:
	ctx.begin_task("Hexagon oluştur", "Hexagon oluştur")
	ctx.get_transcript().record("clarification_requested", {"question": "2D mi 3D mi?", "options": ["2D", "3D"], "id": "c1"})
	ctx.get_transcript().record("clarification_answered", {"answer": "3D yap"})
	ctx.add_assistant_tool_call_message("", [{"name": "propose_plan", "arguments": {"goal": "3D hex grid", "affected_files": ["res://HexCell.gd"], "steps": [{"title": "Create HexCell"}, {"title": "Validate"}]}}])
	ctx.get_transcript().record("plan_proposed", {"steps": 2, "files": 1, "goal": "3D hex grid"})
	ctx.get_transcript().record("plan_approved", {})
	ctx.get_transcript().record("tool_executing", {"tool": "read_script", "title": "Read script: HexCell.gd", "args": "{}"})
	ctx.add_tool_result_message("call_1", "read_script", {"success": true, "data": {}, "message": "Read script: HexCell.gd"})
	ctx.get_transcript().record("tool_completed", {"tool": "read_script", "title": "Read script: HexCell.gd", "success": true, "error": ""})
	ctx.get_transcript().record("verification_completed", {"tool": "validate_script", "valid": true, "message": "Validated GDScript source"})
	ctx.end_task("completed", "", {"success": true, "steps_summary": "3 / 20", "tool_calls": 2})

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Basit session export (user + assistant, task sınırlı)
	var ctx1 = AISidebarAgentContext.new()
	ctx1.begin_task("Selam", "")
	ctx1.add_user_message("Selam", false, "", [])
	ctx1.add_assistant_message("Merhaba, nasıl yardımcı olabilirim?")
	ctx1.end_task("completed", "", {"success": true})
	var md1 = AISidebarChatExporter.export_transcript_to_markdown(ctx1.get_transcript().to_data(), ctx1.messages, {})
	if "## Task 1" in md1 and "Selam" in md1 and "Merhaba" in md1 and "### User" in md1 and "### Assistant" in md1:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (simple session export) failed.")

	# 2. Tool call + result export
	var ctx2 = AISidebarAgentContext.new()
	_make_full_task(ctx2)
	var md2 = AISidebarChatExporter.export_transcript_to_markdown(ctx2.get_transcript().to_data(), [], {})
	if "### Tool Calls" in md2 and "read_script" in md2 and "### Tool Results" in md2 and "Read script: HexCell.gd" in md2:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (tool call+result export) failed.")

	# 3. Clarification export (soru + cevap)
	if "### Clarification" in md2 and "2D mi 3D mi?" in md2 and "3D yap" in md2:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (clarification export) failed.")

	# 4. Plan + approval export
	if "### Plan" in md2 and "3D hex grid" in md2 and "Plan approved" in md2 and "Create HexCell" in md2:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (plan+approval export) failed.")

	# 5. Failure/cancellation export (stop reason korunur)
	var ctx5 = AISidebarAgentContext.new()
	ctx5.begin_task("Riskli iş", "")
	ctx5.add_user_message("Riskli iş", false, "", [])
	ctx5.get_transcript().record("tool_completed", {"tool": "create_or_update_script", "title": "Updated script", "success": false, "error": "Parse error at line 12"})
	ctx5.end_task("failed", "Parse error at line 12")
	ctx5.begin_task("Vazgeçilen iş", "")
	ctx5.end_task("cancelled", "User stopped the task.")
	var md5 = AISidebarChatExporter.export_transcript_to_markdown(ctx5.get_transcript().to_data(), [], {})
	if "failed" in md5 and "Parse error at line 12" in md5 and "cancelled" in md5 and "User stopped" in md5 and "### Completion" in md5:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (failure/cancellation export) failed.")

	# 6. Task boundary ayrımı + session roundtrip
	var ctx6 = AISidebarAgentContext.new()
	ctx6.begin_task("İlk görev", "")
	ctx6.add_user_message("İlk görev", false, "", [])
	ctx6.end_task("completed", "", {"success": true})
	ctx6.begin_task("İkinci görev", "")
	ctx6.add_user_message("İkinci görev", false, "", [])
	ctx6.end_task("completed", "", {"success": true})
	var sess = AISidebarChatSession.new("s1", "T")
	sess.transcript_tasks = ctx6.get_transcript().to_data()
	var restored = AISidebarChatSession.from_dict(sess.to_dict())
	var md6 = AISidebarChatExporter.export_transcript_to_markdown(restored.transcript_tasks, [], {})
	var t1_pos = md6.find("## Task 1")
	var t2_pos = md6.find("## Task 2")
	var first_in_t1 = md6.find("İlk görev")
	var second_pos = md6.find("İkinci görev")
	if t1_pos >= 0 and t2_pos > t1_pos and first_in_t1 > t1_pos and first_in_t1 < t2_pos and second_pos > t2_pos:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (task boundary + roundtrip) failed.")

	# 7. 20+ mesaj compaction'a rağmen full transcript korunur
	var ctx7 = AISidebarAgentContext.new()
	ctx7.begin_task("Uzun görev", "")
	for i in range(25):
		ctx7.add_user_message("Adım isteği %d" % i, false, "", [])
		ctx7.add_tool_result_message("call_%d" % i, "read_script", {"success": true, "data": {}, "message": "ok %d" % i})
	ctx7.end_task("completed", "", {"success": true})
	var compacted = ctx7.messages.size() < 51
	var md7 = AISidebarChatExporter.export_transcript_to_markdown(ctx7.get_transcript().to_data(), ctx7.messages, {})
	if compacted and "Adım isteği 0" in md7 and "Adım isteği 24" in md7 and ctx7.get_transcript().task_count() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("T7 (compaction survival) failed: msgs=%d tasks=%d" % [ctx7.messages.size(), ctx7.get_transcript().task_count()])

	# 8. Export'ta secret/token redaction
	var ctx8 = AISidebarAgentContext.new()
	ctx8.begin_task("Gizli görev", "")
	ctx8.get_transcript().record("tool_executing", {"tool": "mcp_call", "title": "Calling remote", "args": "{\"api_key\": \"sk-live-999\", \"q\": \"hi\"} Authorization: Bearer abcdef123456"})
	ctx8.end_task("completed", "", {"success": true})
	var md8 = AISidebarChatExporter.export_transcript_to_markdown(ctx8.get_transcript().to_data(), [], {})
	if not "sk-live-999" in md8 and not "abcdef123456" in md8 and "[REDACTED]" in md8:
		passed += 1
	else:
		failed += 1
		errors.append("T8 (redaction) failed.")

	# 9. Markdown ve JSON aynı complete transcripti temsil ediyor
	var tasks9 = ctx2.get_transcript().to_data()
	var md9 = AISidebarChatExporter.export_transcript_to_markdown(tasks9, [], {})
	var js9 = AISidebarChatExporter.export_transcript_to_json(tasks9, [], {})
	var parsed9 = JSON.parse_string(js9)
	if parsed9 is Dictionary and str(parsed9.get("export_version", "")) == "3.0" and (parsed9.get("tasks", []) as Array).size() == 1 and "3D hex grid" in md9 and "3D hex grid" in js9 and "2D mi 3D mi?" in js9:
		passed += 1
	else:
		failed += 1
		errors.append("T9 (md/json parity) failed.")

	# 10. Empty/null safety
	var md10a = AISidebarChatExporter.export_transcript_to_markdown([], [], {})
	var md10b = AISidebarChatExporter.export_transcript_to_markdown([null, {}, {"display_prompt": "X", "status": "completed", "events": [null, {"t": "bogus_type", "data": null}]}], [null, {}], {})
	var js10 = AISidebarChatExporter.export_transcript_to_json([], [], {})
	if "# 🤖 Godot AI Chat Export" in md10a and "## Task 1" in md10b and JSON.parse_string(js10) is Dictionary:
		passed += 1
	else:
		failed += 1
		errors.append("T10 (empty/null safety) failed.")

	# 12. Normal tool arguments export ediliyor (sadece plan/ask_user değil)
	var ctx12 = AISidebarAgentContext.new()
	ctx12.begin_task("Script yaz", "")
	ctx12.add_assistant_tool_call_message("", [{"name": "create_or_update_script", "arguments": {"file_path": "res://HexCell.gd", "content": "extends Node3D\n"}}])
	ctx12.end_task("completed", "", {"success": true})
	var tasks12 = ctx12.get_transcript().to_data()
	var md12 = AISidebarChatExporter.export_transcript_to_markdown(tasks12, [], {})
	var js12 = AISidebarChatExporter.export_transcript_to_json(tasks12, [], {})
	if "HexCell.gd" in md12 and "extends Node3D" in md12 and "HexCell.gd" in js12 and "extends Node3D" in js12:
		passed += 1
	else:
		failed += 1
		errors.append("T12 (normal tool args export) failed.")

	# 13. Tool result payload export ediliyor (message ötesi veri)
	var ctx13 = AISidebarAgentContext.new()
	ctx13.begin_task("Dosya yaz", "")
	ctx13.add_tool_result_message("call_9", "create_or_update_script", {"success": true, "data": {"file_path": "res://HexCell.gd", "action": "created", "lines": 42}, "message": "Script created."})
	ctx13.end_task("completed", "", {"success": true})
	var tasks13 = ctx13.get_transcript().to_data()
	var md13 = AISidebarChatExporter.export_transcript_to_markdown(tasks13, [], {})
	var js13 = AISidebarChatExporter.export_transcript_to_json(tasks13, [], {})
	if "Payload" in md13 and "created" in md13 and "42" in js13 and "HexCell.gd" in js13:
		passed += 1
	else:
		failed += 1
		errors.append("T13 (tool result payload export) failed.")

	# 14. Nested secret redaction çalışıyor
	var nested = {"auth": {"api_key": "sk-nested-123", "user": "u"}, "items": [{"password": "pw-456"}, "safe"], "token": "tok-789"}
	var clean14 = AISidebarChatExporter.redact_recursive(nested)
	var flat14 = JSON.stringify(clean14)
	if not "sk-nested-123" in flat14 and not "pw-456" in flat14 and not "tok-789" in flat14 and clean14["auth"]["user"] == "u" and clean14["items"][1] == "safe" and "[REDACTED]" in flat14:
		passed += 1
	else:
		failed += 1
		errors.append("T14 (nested redaction) failed: " + flat14)

	# 15. Markdown ve JSON secret sızdırmıyor (args + history + metadata)
	var ctx15 = AISidebarAgentContext.new()
	ctx15.begin_task("Uzak çağrı", "")
	ctx15.add_assistant_tool_call_message("", [{"name": "mcp_call", "arguments": {"api_key": "sk-live-555", "target": "srv"}}])
	ctx15.add_tool_result_message("call_m", "mcp_call", {"success": true, "data": {"session_token": "sess-666"}, "message": "done"})
	ctx15.end_task("completed", "", {"success": true})
	var tasks15 = ctx15.get_transcript().to_data()
	var hist15 = [{"role": "user", "content": "call with password=hunter2 inside"}, {"role": "assistant", "content": "Bearer abcdef123456 used"}]
	var meta15 = {"model": "x", "refresh_token": "rt-777"}
	var md15 = AISidebarChatExporter.export_transcript_to_markdown(tasks15, hist15, meta15)
	var js15 = AISidebarChatExporter.export_transcript_to_json(tasks15, hist15, meta15)
	var leaks = ["sk-live-555", "sess-666", "hunter2", "abcdef123456", "rt-777"]
	var leaked15 = false
	for s in leaks:
		if s in md15 or s in js15:
			leaked15 = true
	if not leaked15 and "[REDACTED]" in md15 and "[REDACTED]" in js15:
		passed += 1
	else:
		failed += 1
		errors.append("T15 (md+json no-leak) failed.")

	# 16. Truncation deterministik (bayrak + marker + tekrarlanabilirlik)
	var big_args = {"file_path": "res://Big.gd", "content": "x".repeat(20000), "api_key": "sk-big-888"}
	var ctx16 = AISidebarAgentContext.new()
	ctx16.begin_task("Büyük yazım", "")
	ctx16.add_assistant_tool_call_message("", [{"name": "create_or_update_script", "arguments": big_args}])
	ctx16.end_task("completed", "", {"success": true})
	var ev16 = ctx16.get_transcript().to_data()[0]["events"]
	var call_ev = {}
	for e in ev16:
		if e is Dictionary and str(e.get("t", "")) == "tool_call":
			call_ev = e
	var c0 = (call_ev.get("data", {}).get("calls", []) as Array)[0]
	var md16a = AISidebarChatExporter.export_transcript_to_markdown(ctx16.get_transcript().to_data(), [], {})
	var md16b = AISidebarChatExporter.export_transcript_to_markdown(ctx16.get_transcript().to_data(), [], {})
	if bool(c0.get("args_truncated", false)) and "[truncated]" in str(c0.get("args", "")) and not "sk-big-888" in str(c0.get("args", "")) and md16a == md16b and "[REDACTED]" in md16a:
		passed += 1
	else:
		failed += 1
		errors.append("T16 (deterministic truncation) failed.")

	# 17. Compaction sonrasında full task data (args + payload) hâlâ export ediliyor
	var ctx17 = AISidebarAgentContext.new()
	ctx17.begin_task("Uzun inşa", "")
	ctx17.add_assistant_tool_call_message("", [{"name": "create_or_update_script", "arguments": {"file_path": "res://Keep1.gd", "content": "UNIQUE_MARKER_ARGS_17"}}])
	ctx17.add_tool_result_message("call_k", "create_or_update_script", {"success": true, "data": {"file_path": "res://Keep1.gd", "marker": "UNIQUE_MARKER_PAYLOAD_17"}, "message": "ok"})
	for i in range(25):
		ctx17.add_user_message("Dolgu %d" % i, false, "", [])
		ctx17.add_tool_result_message("call_f%d" % i, "read_script", {"success": true, "data": {}, "message": "ok"})
	ctx17.end_task("completed", "", {"success": true})
	var md17 = AISidebarChatExporter.export_transcript_to_markdown(ctx17.get_transcript().to_data(), ctx17.messages, {})
	var js17 = AISidebarChatExporter.export_transcript_to_json(ctx17.get_transcript().to_data(), ctx17.messages, {})
	if ctx17.messages.size() < 53 and "UNIQUE_MARKER_ARGS_17" in md17 and "UNIQUE_MARKER_PAYLOAD_17" in md17 and "UNIQUE_MARKER_ARGS_17" in js17 and "UNIQUE_MARKER_PAYLOAD_17" in js17:
		passed += 1
	else:
		failed += 1
		errors.append("T17 (compaction full-data survival) failed: msgs=%d" % ctx17.messages.size())

	return {"name": "EverythingExportTests", "passed": passed, "failed": failed, "errors": errors}
