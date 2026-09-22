@tool
extends RefCounted

## Multi-tool call kaybı + play_game main-scene guard için DETERMINISTIK testler.
## Aynı response'taki TÜM çağrılar sıralı işlenir; kullanıcı kapısında kalanlar
## DEFERRED kaydıyla context'e yazılır (sessiz kayıp yok, kör icra yok).

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarRuntimeDebugger = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_debugger.gd")

class MockBatchProvider extends AISidebarAIProvider:
	var response_queue: Array = []
	var recorded_messages: Array = []

	func send_chat(messages: Array, tools_schema: Array) -> void:
		recorded_messages.append(messages.duplicate(true))
		if response_queue.size() > 0:
			var r = response_queue.pop_front()
			response_received.emit(
				r.get("content", ""),
				r.get("thinking", ""),
				r.get("tool_calls", [])
			)

static func _tool_ids_in_order(ctx) -> Array:
	var out: Array = []
	for m in ctx.messages:
		if m is Dictionary and str(m.get("role", "")) == "tool":
			out.append(str(m.get("tool_call_id", "")))
	return out

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Aynı response'taki 3 çağrı da kaybolmadan, sırasıyla, TEK step'te işlenir
	var mock1 = MockBatchProvider.new()
	var ctx1 = AISidebarAgentContext.new()
	var runner1 = AISidebarAgentRunner.new(mock1, ctx1)
	mock1.response_queue = [
		{"content": "", "thinking": "", "tool_calls": [
			{"id": "call_a", "name": "analyze_project", "arguments": {}},
			{"id": "call_b", "name": "get_project_files", "arguments": {}},
			{"id": "call_c", "name": "analyze_project", "arguments": {"detail": "x"}},
		]},
		{"content": "Üç araç da tamamlandı.", "thinking": "", "tool_calls": []},
	]
	runner1.start_task("Projeyi incele.")
	var ids1 = _tool_ids_in_order(ctx1)
	if mock1.recorded_messages.size() == 2 and ids1 == ["call_a", "call_b", "call_c"]:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (batch kept in one step, ordered) failed: steps=%d ids=%s" % [mock1.recorded_messages.size(), str(ids1)])

	# 2. Batch sonrası verification/context zinciri bozulmuyor (ikinci tur modeli görüyor)
	var step2_has_all_results = false
	if mock1.recorded_messages.size() >= 2:
		var seen = {}
		for m in mock1.recorded_messages[1]:
			if m is Dictionary and str(m.get("role", "")) == "tool" and str(m.get("tool_call_id", "")) in ["call_a", "call_b", "call_c"]:
				seen[str(m.get("tool_call_id", ""))] = true
		step2_has_all_results = seen.size() == 3
	if step2_has_all_results:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (all results visible next turn) failed.")

	# 3. Clarification kapısında kalan çağrı DEFERRED kaydıyla durur, kör icra yok
	var mock3 = MockBatchProvider.new()
	var ctx3 = AISidebarAgentContext.new()
	var runner3 = AISidebarAgentRunner.new(mock3, ctx3)
	var clar_asked: Array = []
	runner3.clarification_requested.connect(func(q, o, i): clar_asked.append(str(q)))
	mock3.response_queue = [
		{"content": "", "thinking": "", "tool_calls": [
			{"id": "call_q", "name": "ask_user", "arguments": {"question": "Hangisi?", "options": ["A", "B"]}},
			{"id": "call_r", "name": "analyze_project", "arguments": {}},
		]},
		{"content": "Yanıt alındı, bitti.", "thinking": "", "tool_calls": []},
	]
	runner3.start_task("Belirsiz görev.")
	var waiting_ok = clar_asked.size() == 1
	var deferred_ok = false
	var real_exec_ok = true
	for m in ctx3.messages:
		if m is Dictionary and str(m.get("role", "")) == "tool" and str(m.get("tool_call_id", "")) == "call_r":
			var parsed = JSON.parse_string(str(m.get("content", "{}")))
			if parsed is Dictionary and str(parsed.get("error", {}).get("code", "")) == "DEFERRED_FOR_CLARIFICATION":
				deferred_ok = true
			else:
				real_exec_ok = false
	if waiting_ok and deferred_ok and real_exec_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (clarification defers rest) failed: asked=%d deferred=%s noexec=%s" % [clar_asked.size(), str(deferred_ok), str(real_exec_ok)])
	runner3.submit_clarification_response("A")
	if runner3.current_state == AISidebarAgentRunner.AgentState.IDLE:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (resume after clarification) failed: state=%d" % runner3.current_state)

	# 5. _defer_remaining_calls birimi: her çağrıya kayıt + sinyal, kuyruk temiz
	var ctx5 = AISidebarAgentContext.new()
	var runner5 = AISidebarAgentRunner.new(MockBatchProvider.new(), ctx5)
	var emitted5: Array = []
	runner5.tool_completed.connect(func(n, r): emitted5.append(str(n)))
	runner5._defer_remaining_calls(
		[{"name": "write_files", "id": "d1", "args": {}}, {"name": "validate_script", "id": "d2", "args": {}}],
		"DEFERRED_FOR_APPROVAL", "Onay bekleniyor."
	)
	var codes5: Array = []
	for m in ctx5.messages:
		if m is Dictionary and str(m.get("role", "")) == "tool":
			var p = JSON.parse_string(str(m.get("content", "{}")))
			if p is Dictionary:
				codes5.append(str(p.get("error", {}).get("code", "")))
	if codes5 == ["DEFERRED_FOR_APPROVAL", "DEFERRED_FOR_APPROVAL"] and emitted5 == ["write_files", "validate_script"]:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (defer unit) failed: codes=%s emitted=%s" % [str(codes5), str(emitted5)])

	# 6. Main scene yoksa guard kapalı yakalar (test projesinde main_scene tanımsız)
	var chk = AISidebarRuntimeDebugger.check_main_scene_available()
	if chk is Dictionary and not bool(chk.get("available", true)):
		passed += 1
	else:
		failed += 1
		errors.append("T6 (main scene detection) failed: " + str(chk))

	# 7. Headless'te play() sırası korunuyor (önce EDITOR_REQUIRED)
	var dbg = AISidebarRuntimeDebugger.new()
	var play_res = dbg.play(false)
	if not bool(play_res.get("success", true)) and str(play_res.get("error", {}).get("code", "")) == "EDITOR_REQUIRED":
		passed += 1
	else:
		failed += 1
		errors.append("T7 (editor guard order) failed: " + str(play_res.get("error", {})))

	return {"name": "MultiToolAndSceneGuardTests", "passed": passed, "failed": failed, "errors": errors}
