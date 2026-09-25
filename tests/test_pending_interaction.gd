@tool
extends RefCounted

## Bekleyen kullanıcı kararları (Refactor Faz 2.2 sabitleme testleri): onay / netleştirme / plan
## isteğinin saklanması, karar fonksiyonlarının koruma koşulları (yanlış durumda etkisiz),
## kararın context'e tool sonucu olarak yazılması, yeni task / stop / task sonu temizliği.
## Provider elle yanıtlar; ağ ve editör kullanılmaz.

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")

class ManualProvider extends AISidebarAIProvider:
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		pass
	func respond(text: String, tool_calls: Array = []) -> void:
		response_received.emit(text, "", tool_calls)

static func _new_runner() -> Dictionary:
	var p = ManualProvider.new()
	var ctx = AISidebarAgentContext.new()
	var r = AISidebarAgentRunner.new(p, ctx)
	r.enable_planning_gate = false
	return {"runner": r, "provider": p, "ctx": ctx}

## Son tool mesajı (role=tool): {id, name, result}.
static func _last_tool_msg(ctx) -> Dictionary:
	for i in range(ctx.messages.size() - 1, -1, -1):
		var m = ctx.messages[i]
		if str(m.get("role", "")) == "tool":
			return {"id": str(m.get("tool_call_id", "")), "name": str(m.get("name", "")), "result": JSON.parse_string(str(m.get("content", "{}")))}
	return {}

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Onay isteği: aynı args ve change set onayda aynen kullanılır; yanlış durumda karar etkisiz
	var s1 = _new_runner()
	var r1 = s1["runner"]
	var executed: Array = []
	var requested: Array = []
	r1.tool_executing.connect(func(n, a): executed.append([n, a]))
	r1.approval_requested.connect(func(n, a, cs): requested.append([n, a, cs]))
	r1.start_task("Sil")
	var del_args = {"node_path": "TempNode"}
	s1["provider"].respond("", [{"id": "d1", "name": "delete_node", "arguments": del_args}])
	var waiting = r1.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL and requested.size() == 1 and requested[0][2] != null
	executed.clear()
	# Yanlış durumdaki kararlar etkisiz: plan / netleştirme kararları bekleyen onayı bozmaz
	r1.approve_plan()
	r1.submit_clarification_response("x")
	var untouched = r1.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL and executed.is_empty()
	r1.approve_pending_action()
	var same_args = executed.size() == 1 and executed[0][0] == "delete_node" and executed[0][1] == del_args
	var tm1 = _last_tool_msg(s1["ctx"])
	var ctx_ok = tm1.get("id", "") == "d1" and tm1.get("name", "") == "delete_node"
	# Karar bir kez tüketilir: ikinci onay etkisiz
	executed.clear()
	r1.approve_pending_action()
	var consumed = executed.is_empty()
	if waiting and untouched and same_args and ctx_ok and consumed:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (approval request/approve) failed: waiting=%s untouched=%s args=%s ctx=%s consumed=%s" % [str(waiting), str(untouched), str(same_args), str(ctx_ok), str(consumed)])
	if r1.is_running():
		r1.stop()

	# 2. Onay reddi: USER_REJECTED sonucu aynı çağrı kimliğiyle context'e yazılır, tool çalışmaz
	var s2 = _new_runner()
	var r2 = s2["runner"]
	var exec2: Array = []
	r2.start_task("Sil")
	s2["provider"].respond("", [{"id": "d2", "name": "delete_node", "arguments": {"node_path": "TempNode"}}])
	r2.tool_executing.connect(func(n, _a): exec2.append(n))
	r2.reject_pending_action("Hayır")
	var tm2 = _last_tool_msg(s2["ctx"])
	var res2: Dictionary = tm2.get("result", {}) if tm2.get("result", {}) is Dictionary else {}
	var reject_ok = exec2.is_empty() and tm2.get("id", "") == "d2" and tm2.get("name", "") == "delete_node" and str((res2.get("error", {}) as Dictionary).get("code", "")) == "USER_REJECTED" and r2.current_state != AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL
	r2.reject_pending_action("Tekrar")
	var reject_once = _last_tool_msg(s2["ctx"]).get("id", "") == "d2" and s2["ctx"].messages.filter(func(m): return str(m.get("role", "")) == "tool").size() == 1
	if reject_ok and reject_once:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (approval reject) failed: reject=%s once=%s msg=%s" % [str(reject_ok), str(reject_once), str(tm2)])
	if r2.is_running():
		r2.stop()

	# 3. Netleştirme: soru + cevap aynı çağrı kimliğiyle ask_user sonucu olarak yazılır;
	# ikinci cevap etkisiz; seçenekler sinyalle gelen dizidir
	var s3 = _new_runner()
	var r3 = s3["runner"]
	var asked: Array = []
	r3.clarification_requested.connect(func(q, o, id): asked.append([q, o.duplicate(), id]))
	r3.start_task("Sor")
	s3["provider"].respond("", [{"id": "q1", "name": "ask_user", "arguments": {"question": "Hangisi?", "options": ["A", 2]}}])
	var asked_ok = asked.size() == 1 and asked[0][0] == "Hangisi?" and asked[0][1] == ["A", "2"] and asked[0][2] == "q1"
	r3.approve_pending_action()
	r3.reject_plan()
	var still_waiting = r3.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_CLARIFICATION
	r3.submit_clarification_response("A")
	var tm3 = _last_tool_msg(s3["ctx"])
	var res3: Dictionary = tm3.get("result", {}) if tm3.get("result", {}) is Dictionary else {}
	var data3: Dictionary = res3.get("data", {}) if res3.get("data", {}) is Dictionary else {}
	var answer_ok = tm3.get("id", "") == "q1" and tm3.get("name", "") == "ask_user" and data3.get("question", "") == "Hangisi?" and data3.get("user_answer", "") == "A" and str(res3.get("message", "")) == "Kullanıcı yanıtı: A"
	var tool_msgs3 = s3["ctx"].messages.filter(func(m): return str(m.get("role", "")) == "tool").size()
	r3.submit_clarification_response("B")
	var answered_once = s3["ctx"].messages.filter(func(m): return str(m.get("role", "")) == "tool").size() == tool_msgs3
	if asked_ok and still_waiting and answer_ok and answered_once:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (clarification) failed: asked=%s waiting=%s answer=%s once=%s msg=%s" % [str(asked_ok), str(still_waiting), str(answer_ok), str(answered_once), str(tm3)])
	if r3.is_running():
		r3.stop()

	# 4. Plan: onay sinyali sunulan plan nesnesini taşır; onay sonucu plan çağrı kimliğiyle yazılır
	var s4 = _new_runner()
	var r4 = s4["runner"]
	var proposed: Array = []
	var approved: Array = []
	r4.plan_proposed.connect(func(p): proposed.append(p))
	r4.plan_approved.connect(func(p): approved.append(p))
	r4.start_task("Plan")
	s4["provider"].respond("", [{"id": "pl1", "name": "propose_plan", "arguments": {"goal": "G", "steps": ["a"]}}])
	r4.approve_pending_action()
	r4.submit_clarification_response("x")
	var plan_waiting = r4.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL
	r4.approve_plan()
	var tm4 = _last_tool_msg(s4["ctx"])
	var res4: Dictionary = tm4.get("result", {}) if tm4.get("result", {}) is Dictionary else {}
	var plan_ok = proposed.size() == 1 and approved.size() == 1 and approved[0] == proposed[0] and tm4.get("id", "") == "pl1" and tm4.get("name", "") == "propose_plan" and bool((res4.get("data", {}) as Dictionary).get("approved", false))
	approved.clear()
	r4.approve_plan()
	var plan_once = approved.is_empty()
	if plan_waiting and plan_ok and plan_once:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (plan approve) failed: waiting=%s plan=%s once=%s msg=%s" % [str(plan_waiting), str(plan_ok), str(plan_once), str(tm4)])
	if r4.is_running():
		r4.stop()

	# 5. Stop tüm bekleyen kararları temizler: sonraki kararlar etkisiz, sonuç yazılmaz
	var s5 = _new_runner()
	var r5 = s5["runner"]
	r5.start_task("Sil")
	s5["provider"].respond("", [{"id": "d5", "name": "delete_node", "arguments": {"node_path": "TempNode"}}])
	var tools_before = s5["ctx"].messages.filter(func(m): return str(m.get("role", "")) == "tool").size()
	r5.stop()
	r5.current_state = AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL
	var exec5: Array = []
	r5.tool_executing.connect(func(n, _a): exec5.append(n))
	r5.approve_pending_action()
	r5.reject_pending_action()
	var stop_cleared = exec5.is_empty() and s5["ctx"].messages.filter(func(m): return str(m.get("role", "")) == "tool").size() == tools_before
	r5.current_state = AISidebarAgentRunner.AgentState.IDLE
	if stop_cleared:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (stop clears pending) failed: exec=%s" % str(exec5))

	# 6. Task sonu yalnızca netleştirmeyi temizler; yeni task her şeyi temizler
	var s6 = _new_runner()
	var r6 = s6["runner"]
	r6.start_task("Sor")
	s6["provider"].respond("", [{"id": "q6", "name": "ask_user", "arguments": {"question": "?", "options": []}}])
	r6._finish_task(false)
	r6.current_state = AISidebarAgentRunner.AgentState.WAITING_FOR_CLARIFICATION
	var tools6 = s6["ctx"].messages.filter(func(m): return str(m.get("role", "")) == "tool").size()
	r6.submit_clarification_response("geç")
	var finish_cleared_clar = s6["ctx"].messages.filter(func(m): return str(m.get("role", "")) == "tool").size() == tools6
	r6.current_state = AISidebarAgentRunner.AgentState.IDLE
	# Bekleyen onay task sonunda kalır (yalnızca WAITING_FOR_APPROVAL'da kullanılabilir) ...
	var s7 = _new_runner()
	var r7 = s7["runner"]
	r7.start_task("Sil")
	s7["provider"].respond("", [{"id": "d7", "name": "delete_node", "arguments": {"node_path": "TempNode"}}])
	r7._finish_task(false)
	r7.current_state = AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL
	var exec7: Array = []
	r7.tool_executing.connect(func(n, _a): exec7.append(n))
	r7.reject_pending_action()
	var approval_kept = _last_tool_msg(s7["ctx"]).get("id", "") == "d7" and str(((_last_tool_msg(s7["ctx"]).get("result", {}) as Dictionary).get("error", {}) as Dictionary).get("code", "")) == "USER_REJECTED"
	if r7.is_running():
		r7.stop()
	# ... ama yeni task onu siler
	r7.start_task("Yeni")
	r7.current_state = AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL
	var tools7 = s7["ctx"].messages.filter(func(m): return str(m.get("role", "")) == "tool").size()
	r7.reject_pending_action()
	var start_cleared = s7["ctx"].messages.filter(func(m): return str(m.get("role", "")) == "tool").size() == tools7
	r7.current_state = AISidebarAgentRunner.AgentState.IDLE
	if finish_cleared_clar and approval_kept and start_cleared:
		passed += 1
	else:
		failed += 1
		errors.append("T6 (finish/start clearing) failed: finish_clar=%s approval_kept=%s start=%s" % [str(finish_cleared_clar), str(approval_kept), str(start_cleared)])

	return {"name": "PendingInteractionTests", "passed": passed, "failed": failed, "errors": errors}
