@tool
extends RefCounted

## İki bağımsız AgentRunner (Refactor Faz 2.4): aynı süreçte iç içe çalışan iki runner'ın
## context, telemetri, bekleyen kararlar, tekrar koruması, açılan araçlar, durum ve sinyalleri
## birbirine karışmaz. İki AgentHost da ayrı NetworkManager / provider / runner taşır.
## Alt ajanların (ürün Faz 10) ve CLI / MCP köprüsünün (ürün Faz 7) önkoşulu.
## Bilinçli olarak paylaşılan durum (runtime izleme, kayıt defterleri) docs/REFACTOR_PLAN.md'de.

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAgentHost = preload("res://addons/godot_sidebar_ai/core/agent/agent_host.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")

const MISSING = "res://tests/__indep_missing__.gd"

class ManualProvider extends AISidebarAIProvider:
	var sent: int = 0
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		sent += 1
	func respond(text: String, tool_calls: Array = []) -> void:
		response_received.emit(text, "", tool_calls)

static func _pair() -> Array:
	var out: Array = []
	for i in 2:
		var p = ManualProvider.new()
		var ctx = AISidebarAgentContext.new()
		var r = AISidebarAgentRunner.new(p, ctx)
		r.enable_planning_gate = false
		var log: Array = []
		r.task_completed.connect(func(m): log.append("completed:" + str(m.get("completion"))))
		r.tool_executing.connect(func(n, _a): log.append("exec:" + n))
		r.plan_approved.connect(func(_p): log.append("plan_approved"))
		out.append({"runner": r, "provider": p, "ctx": ctx, "log": log})
	return out

static func _call(id: String, name: String, args: Dictionary = {}) -> Dictionary:
	return {"id": id, "name": name, "arguments": args}

static func _user_texts(ctx) -> Array:
	var out: Array = []
	for m in ctx.messages:
		if str(m.get("role", "")) == "user":
			out.append(str(m.get("content", "")))
	return out

static func _tool_codes(ctx) -> Array:
	var out: Array = []
	for m in ctx.messages:
		if str(m.get("role", "")) == "tool":
			var res = JSON.parse_string(str(m.get("content", "{}")))
			var code = ""
			if res is Dictionary and res.get("error", null) is Dictionary:
				code = str(res["error"].get("code", ""))
			out.append(str(m.get("tool_call_id", "")) + ":" + code)
	return out

static func _stop_all(pair: Array) -> void:
	for s in pair:
		if s["runner"].is_running():
			s["runner"].stop()

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. İç içe görevler: A soru bekliyor, bu sırada B bir tool çalıştırıp bitiyor.
	# A'nın durumu, bekleyen sorusu, context'i ve telemetrisi B'den etkilenmez.
	var p1 = _pair()
	var a = p1[0]
	var b = p1[1]
	a["runner"].start_task("A görevi")
	b["runner"].start_task("B görevi")
	a["provider"].respond("", [_call("a1", "ask_user", {"question": "A mı?", "options": ["evet"]})])
	b["provider"].respond("", [_call("b1", "read_script", {"file_path": MISSING})])
	b["provider"].respond("B bitti.")
	var a_ok = (a["runner"].current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_CLARIFICATION
		and a["runner"].pending.clarification_id == "a1"
		and a["runner"].telemetry.tool_calls_count == 1 and a["runner"].current_step == 1
		and a["log"].is_empty() and _user_texts(a["ctx"]) == ["A görevi"] and _tool_codes(a["ctx"]).is_empty())
	var b_ok = (b["runner"].current_state == AISidebarAgentRunner.AgentState.IDLE
		and not b["runner"].pending.has_clarification()
		and b["runner"].telemetry.tool_calls_count == 1 and b["runner"].current_step == 2
		and b["log"] == ["exec:read_script", "completed:incomplete"]
		and _user_texts(b["ctx"]) == ["B görevi"] and _tool_codes(b["ctx"]) == ["b1:FILE_NOT_FOUND"])
	var separate_units = a["runner"].telemetry != b["runner"].telemetry and a["runner"].pending != b["runner"].pending and a["runner"].runtime_debugger != b["runner"].runtime_debugger
	# A devam eder: yanıtı yalnızca A'nın context'ine yazılır
	a["runner"].submit_clarification_response("evet")
	var a_answer = _tool_codes(a["ctx"]) == ["a1:"] and _tool_codes(b["ctx"]) == ["b1:FILE_NOT_FOUND"]
	if a_ok and b_ok and separate_units and a_answer:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (interleaved tasks) failed: a=%s b=%s units=%s answer=%s a_log=%s b_log=%s" % [str(a_ok), str(b_ok), str(separate_units), str(a_answer), str(a["log"]), str(b["log"])])
	_stop_all(p1)

	# 2. Aynı anda farklı kararlar: A onay, B plan bekliyor. Birinin kararı diğerine uygulanmaz.
	var p2 = _pair()
	a = p2[0]
	b = p2[1]
	a["runner"].start_task("A sil")
	b["runner"].start_task("B planla")
	a["provider"].respond("", [_call("a2", "delete_node", {"node_path": "TempA"})])
	b["provider"].respond("", [_call("b2", "propose_plan", {"goal": "B planı", "steps": ["x"]})])
	b["runner"].approve_pending_action()
	a["runner"].approve_plan()
	var cross_noop = (a["runner"].current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL
		and b["runner"].current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL
		and a["log"] == ["exec:delete_node"] and b["log"].is_empty())
	a["runner"].approve_pending_action()
	var a_done = a["log"] == ["exec:delete_node", "exec:delete_node"] and a["runner"].pending.tool_name.is_empty()
	var b_kept = b["runner"].current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL and b["runner"].pending.plan_id == "b2" and b["runner"].pending.plan.goal == "B planı"
	b["runner"].approve_plan()
	var b_approved = b["log"] == ["plan_approved"] and a["log"].count("plan_approved") == 0
	if cross_noop and a_done and b_kept and b_approved:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (separate pending decisions) failed: cross=%s a_done=%s b_kept=%s b_appr=%s a_log=%s b_log=%s" % [str(cross_noop), str(a_done), str(b_kept), str(b_approved), str(a["log"]), str(b["log"])])
	_stop_all(p2)

	# 3. Tekrar koruması ve açılan araçlar runner başına: A ile B aynı çağrıyı art arda yapar,
	# hiçbiri DUPLICATE_CALL almaz; A'nın search_tools ile açtığı araçlar B'de açılmaz.
	var p3 = _pair()
	a = p3[0]
	b = p3[1]
	a["runner"].start_task("A oku")
	b["runner"].start_task("B oku")
	a["provider"].respond("", [_call("a3", "read_script", {"file_path": MISSING})])
	b["provider"].respond("", [_call("b3", "read_script", {"file_path": MISSING})])
	var no_dup = _tool_codes(a["ctx"]) == ["a3:FILE_NOT_FOUND"] and _tool_codes(b["ctx"]) == ["b3:FILE_NOT_FOUND"] and a["runner"]._stagnation_count == 0 and b["runner"]._stagnation_count == 0
	a["provider"].respond("", [_call("a4", "search_tools", {"query": "camera"})])
	var a_unlocked = a["runner"]._unlocked_tools.size()
	var b_unlocked = b["runner"]._unlocked_tools.duplicate()
	var unlock_separate = a_unlocked > 2 and b_unlocked == ["read_script"]
	if no_dup and unlock_separate:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (stagnation + unlocked tools) failed: no_dup=%s a=%d b=%s codes_a=%s codes_b=%s" % [str(no_dup), a_unlocked, str(b_unlocked), str(_tool_codes(a["ctx"])), str(_tool_codes(b["ctx"]))])
	_stop_all(p3)

	# 4. Stop yalnızca kendi runner'ını durdurur; diğerinin görevi ve bekleyen kararı sürer.
	var p4 = _pair()
	a = p4[0]
	b = p4[1]
	a["runner"].start_task("A")
	b["runner"].start_task("B")
	b["provider"].respond("", [_call("b5", "ask_user", {"question": "B?", "options": []})])
	var b_sent = b["provider"].sent
	a["runner"].stop()
	var stop_isolated = (a["runner"].current_state == AISidebarAgentRunner.AgentState.IDLE and a["log"] == ["completed:cancelled"]
		and b["runner"].is_running() and b["runner"].pending.clarification_id == "b5" and b["log"].is_empty()
		and b["provider"].sent == b_sent)
	if stop_isolated:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (stop isolation) failed: a_state=%s a_log=%s b_running=%s b_log=%s" % [str(a["runner"].current_state), str(a["log"]), str(b["runner"].is_running()), str(b["log"])])
	_stop_all(p4)

	# 5. İki AgentHost: ayrı NetworkManager / context / runner; provider değişimi ve model listesi
	# yalnızca kendi host'unda kalır.
	var h1 = AISidebarAgentHost.new()
	var h2 = AISidebarAgentHost.new()
	var prov1 = ManualProvider.new()
	var prov2 = ManualProvider.new()
	h1.set_provider(prov1)
	h2.set_provider(prov2)
	var got1: Array = []
	var got2: Array = []
	h1.models_fetched.connect(func(m): got1.append(m))
	h2.models_fetched.connect(func(m): got2.append(m))
	prov1.models_fetched.emit(["m1"])
	var hosts_separate = (h1.network_manager != h2.network_manager and h1.context != h2.context and h1.runner != h2.runner
		and h1.runner.provider == prov1 and h2.runner.provider == prov2 and got1 == [["m1"]] and got2.is_empty())
	h1.set_provider(null)
	var h2_kept = h2.runner.provider == prov2 and h2.provider == prov2 and prov2.response_received.is_connected(h2.runner._on_provider_response)
	h1.free()
	h2.free()
	if hosts_separate and h2_kept:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (two hosts) failed: separate=%s kept=%s" % [str(hosts_separate), str(h2_kept)])

	return {"name": "RunnerIndependenceTests", "passed": passed, "failed": failed, "errors": errors}
