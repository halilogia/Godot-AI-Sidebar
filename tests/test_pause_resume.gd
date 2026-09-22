@tool
extends RefCounted

## Pause / Resume checkpoint için DETERMINISTIK testler (A-J).
## Dock rozeti/UI headless kurulamadığından çekirdek bileşim test edilir:
## checkpoint modülü + transcript reopen + runner.resume_task + session roundtrip.

const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")
const AISidebarTaskCheckpoint = preload("res://addons/godot_sidebar_ai/core/chat/task_checkpoint.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")

class MockResumeProvider extends AISidebarAIProvider:
	var responses: Array = []
	func send_chat(messages: Array, tools_schema: Array) -> void:
		if responses.size() > 0:
			var r = responses.pop_front()
			response_received.emit(r.get("content", ""), "", r.get("tool_calls", []))

## S1 analyze ok, S2 create ok, S3 play ok, S4 screenshot TIMEOUT + deferred write.
static func _paused_ctx():
	var ctx = AISidebarAgentContext.new()
	ctx.begin_task("Küp sahnesi hazırla", "")
	ctx.get_transcript().mark_step(1)
	ctx.get_transcript().record("tool_completed", {"tool": "analyze_project", "title": "Analyzed", "success": true, "error": ""})
	ctx.get_transcript().mark_step(2)
	ctx.get_transcript().record("tool_completed", {"tool": "create_scene", "title": "Created", "success": true, "error": ""})
	ctx.get_transcript().mark_step(3)
	ctx.get_transcript().record("tool_completed", {"tool": "play_game", "title": "Started", "success": true, "error": ""})
	ctx.get_transcript().mark_step(4)
	ctx.add_tool_result_message("v1", "take_runtime_screenshot", {"success": false, "error": {"code": "TIMEOUT", "message": "Yanıt zaman aşımı."}, "data": {}})
	ctx.add_tool_result_message("w1", "write_files", {"success": false, "error": {"code": "DEFERRED_FOR_APPROVAL", "message": "Onay bekleniyor, ertelendi."}, "data": {}})
	ctx.get_transcript().record("runtime_observation", {"summary": "Process alive, no errors.", "has_errors": false})
	return ctx

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# A) checkpoint üretimi: tüm alanlar dolu
	var ctx_a = _paused_ctx()
	ctx_a.end_task("cancelled", "Kullanıcı durdurdu.")
	var task_a = ctx_a.get_transcript().get_current_task()
	var cp_a = AISidebarTaskCheckpoint.build(task_a, {"current_step": 4, "max_steps": 20, "elapsed_s": 73.0}, "res://Main.tscn")
	if str(cp_a.get("task_id", "")) == str(task_a.get("id", "")) and int(cp_a.get("current_step", 0)) == 4 and int(cp_a.get("max_steps", 0)) == 20 and "analyze_project" in (cp_a.get("completed_tools", [])) and str((cp_a.get("last_failed_tool", {}) as Dictionary).get("tool", "")) == "take_runtime_screenshot" and "write_files" in (cp_a.get("deferred_tools", [])) and "Process alive" in str(cp_a.get("runtime_summary", "")) and str(cp_a.get("active_scene_path", "")) == "res://Main.tscn" and bool(cp_a.get("resumable", false)):
		passed += 1
	else:
		failed += 1
		errors.append("A (checkpoint build) failed: " + str(cp_a).left(300))

	# B) stop -> checkpoint korunur (cancelled + resumable + step)
	if str(cp_a.get("status", "")) == "cancelled" and bool(cp_a.get("resumable", false)) and "durdurdu" in str(cp_a.get("stop_reason", "")).to_lower():
		passed += 1
	else:
		failed += 1
		errors.append("B (stop preserves checkpoint) failed.")

	# C) reopen: aynı id, task sayısı değişmez; bilinmeyen id false
	var tr_c = ctx_a.get_transcript()
	var n_before = tr_c.task_count()
	var tid = str(task_a.get("id", ""))
	if tr_c.reopen_task(tid) and tr_c.task_count() == n_before and str(tr_c.get_current_task().get("id", "")) == tid and str(tr_c.get_current_task().get("status", "")) == "running" and not tr_c.reopen_task("nope") and not tr_c.reopen_task(""):
		passed += 1
	else:
		failed += 1
		errors.append("C (reopen same id) failed.")

	# D) resume: step korunur (4->5), task_id değişmez, yeni task yok
	var ctx_d = _paused_ctx()
	ctx_d.end_task("cancelled", "Kullanıcı durdurdu.")
	var task_d = ctx_d.get_transcript().get_current_task()
	var cp_d = AISidebarTaskCheckpoint.build(task_d, {"current_step": 4, "max_steps": 20, "elapsed_s": 10.0}, "")
	var mock_d = MockResumeProvider.new()
	mock_d.responses = [{"content": "Devam ediyorum, ekran görüntüsünü tekrar alıyorum.", "tool_calls": []}]
	var runner_d = AISidebarAgentRunner.new(mock_d, ctx_d)
	var msg_d = AISidebarTaskCheckpoint.build_resume_message(cp_d)
	if runner_d.resume_task(cp_d, msg_d, "devam et") and runner_d.current_step == 5 and ctx_d.get_transcript().task_count() == 1 and str(ctx_d.get_transcript().get_current_task().get("id", "")) == str(task_d.get("id", "")):
		passed += 1
	else:
		failed += 1
		errors.append("D (resume continues step, same id) failed: step=%d tasks=%d" % [runner_d.current_step, ctx_d.get_transcript().task_count()])

	# E) son başarısız tool resume mesajında yeniden denenecek olarak var
	if "take_runtime_screenshot" in msg_d and "YENİDEN DENE" in msg_d:
		passed += 1
	else:
		failed += 1
		errors.append("E (failed tool retried) failed: " + msg_d.left(200))

	# F) tamamlananlar tekrarlanmayacak olarak var
	if "analyze_project" in msg_d and "tekrar" in msg_d.to_lower():
		passed += 1
	else:
		failed += 1
		errors.append("F (completed not repeated) failed.")

	# G) resume komutu yalnızca tam-eşleşmede
	if AISidebarTaskCheckpoint.is_resume_command("devam et") and AISidebarTaskCheckpoint.is_resume_command("  Continue ") and AISidebarTaskCheckpoint.is_resume_command("SÜRDÜR") and not AISidebarTaskCheckpoint.is_resume_command("yeni fikir") and not AISidebarTaskCheckpoint.is_resume_command("devam et lütfen") and not AISidebarTaskCheckpoint.is_resume_command(""):
		passed += 1
	else:
		failed += 1
		errors.append("G (resume command matching) failed.")

	# H) session reload sonrası checkpoint korunur + resumable
	var sess_h = AISidebarChatSession.new("s1", "T")
	sess_h.checkpoint = cp_a
	var restored_h = AISidebarChatSession.from_dict(sess_h.to_dict())
	if restored_h.checkpoint is Dictionary and bool(restored_h.checkpoint.get("resumable", false)) and str(restored_h.checkpoint.get("task_id", "")) == str(cp_a.get("task_id", "")) and int(restored_h.checkpoint.get("current_step", 0)) == 4:
		passed += 1
	else:
		failed += 1
		errors.append("H (session roundtrip) failed.")

	# I) checkpoint yokken güvenli: build({}) boş, resume komutu tek başına task açmaz
	var mock_i = MockResumeProvider.new()
	var ctx_i = AISidebarAgentContext.new()
	var runner_i = AISidebarAgentRunner.new(mock_i, ctx_i)
	if AISidebarTaskCheckpoint.build({}, {}, "").is_empty() and not runner_i.resume_task({}, "x", "devam et") and ctx_i.get_transcript().task_count() == 0:
		passed += 1
	else:
		failed += 1
		errors.append("I (no checkpoint safety) failed.")

	# J) terminal failure resume'a kapalı (limit), recoverable açık (timeout)
	var term_j = AISidebarTaskCheckpoint.is_terminal_failure("Maksimum ajan adım limitine (20) ulaşıldı.")
	var rec_j = AISidebarTaskCheckpoint.is_terminal_failure("Yanıt zaman aşımı.")
	if term_j and not rec_j:
		passed += 1
	else:
		failed += 1
		errors.append("J (terminal vs recoverable) failed.")

	return {"name": "PauseResumeTests", "passed": passed, "failed": failed, "errors": errors}
