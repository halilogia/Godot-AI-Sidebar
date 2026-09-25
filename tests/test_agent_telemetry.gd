@tool
extends RefCounted

## AgentRunner telemetrisi (Refactor Faz 2.1 sabitleme testleri): task sonu metrik sözlüğünün
## anahtar sırası ve alan eşlemesi, bekleme süresinin beş karar yolunda (onay, red, netleştirme,
## plan onayı, plan reddi) birikmesi, LLM süresi, op sınıflandırması + kategori süreleri ve yeni
## task'ta sayaçların sıfırlanması. Provider elle yanıtlar; ağ ve editör kullanılmaz.

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")

## İstekleri tutar; yanıt test tarafından respond() ile verilir.
class ManualProvider extends AISidebarAIProvider:
	var sent: int = 0
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		sent += 1
	func respond(text: String, tool_calls: Array = []) -> void:
		response_received.emit(text, "", tool_calls)

const METRIC_KEYS = ["success", "completion", "completion_reason", "elapsed_seconds", "used_steps",
	"max_steps", "steps_summary", "tools_sent", "total_tools", "tools_ratio", "llm_turns",
	"tool_calls", "file_ops", "editor_ops", "runtime_ops", "verification_checkpoints", "read_ops",
	"search_ops", "write_ops", "failed_tools", "retry_count", "limit_hit", "files_read_count",
	"files_written_count", "files_read", "files_written", "tool_time_by_tool_s", "llm_time_s",
	"tool_time_s", "file_time_s", "editor_time_s", "runtime_time_s", "verification_time_s",
	"waiting_time_s", "research_time_s", "research_overhead_ratio"]

static func _new_runner() -> Dictionary:
	var p = ManualProvider.new()
	var r = AISidebarAgentRunner.new(p, AISidebarAgentContext.new())
	r.enable_planning_gate = false
	return {"runner": r, "provider": p}

## Bekleme başlangıcını geçmişe çeker: çözümde en az ms kadar bekleme birikmeli.
static func _waited(r, ms: int) -> void:
	r._waiting_start_time = Time.get_ticks_msec() - ms

static func _near(value: int, expected: int) -> bool:
	return value >= expected and value < expected + 250

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Metrik sözlüğü: anahtar sırası ve her alanın eşlemesi
	var r1 = AISidebarAgentRunner.new()
	r1.task_start_time_msec = Time.get_ticks_msec() - 20000
	r1.current_step = 7
	r1.max_steps = 20
	r1.last_tools_sent_count = 11
	r1.last_completion = {"verdict": "incomplete", "reason": "Kanıt yok."}
	r1.llm_turns_count = 7
	r1.tool_calls_count = 9
	r1.file_ops_count = 3
	r1.editor_ops_count = 2
	r1.runtime_ops_count = 1
	r1.verification_checkpoints_count = 4
	r1.read_ops_count = 5
	r1.search_ops_count = 6
	r1.write_ops_count = 8
	r1.failed_tool_count = 2
	r1.retry_count = 1
	r1.limit_hit = true
	r1.files_read = {"res://a.gd": true, "res://b.gd": true}
	r1.files_written = {"res://c.gd": true}
	r1.tool_time_by_name = {"read_script": 1500}
	r1.llm_time_msec = 4000
	r1.tool_time_msec = 3000
	r1.file_time_msec = 1500
	r1.editor_time_msec = 700
	r1.runtime_time_msec = 300
	r1.verification_time_msec = 200
	r1.waiting_time_msec = 5000
	r1.research_time_msec = 5000
	var got1: Array = []
	r1.task_completed.connect(func(m): got1.append(m))
	r1._finish_task(false)
	var m1: Dictionary = got1[0] if got1.size() > 0 else {}
	var total_tools = AISidebarToolManager.get_all_schemas().size()
	var expected1 = {
		"success": false, "completion": "incomplete", "completion_reason": "Kanıt yok.",
		"used_steps": 7, "max_steps": 20, "steps_summary": "7 / 20", "tools_sent": 11,
		"total_tools": total_tools, "tools_ratio": "11 / " + str(total_tools), "llm_turns": 7,
		"tool_calls": 9, "file_ops": 3, "editor_ops": 2, "runtime_ops": 1, "verification_checkpoints": 4,
		"read_ops": 5, "search_ops": 6, "write_ops": 8, "failed_tools": 2, "retry_count": 1,
		"limit_hit": true, "files_read_count": 2, "files_written_count": 1,
		"files_read": ["res://a.gd", "res://b.gd"], "files_written": ["res://c.gd"],
		"tool_time_by_tool_s": {"read_script": 1.5}, "llm_time_s": 4.0, "tool_time_s": 3.0,
		"file_time_s": 1.5, "editor_time_s": 0.7, "runtime_time_s": 0.3, "verification_time_s": 0.2,
		"waiting_time_s": 5.0, "research_time_s": 5.0, "research_overhead_ratio": 0.25,
	}
	var mismatched: Array = []
	for k in expected1.keys():
		if not m1.has(k) or str(m1[k]) != str(expected1[k]):
			mismatched.append("%s=%s" % [k, str(m1.get(k, "<yok>"))])
	var elapsed_ok = abs(float(m1.get("elapsed_seconds", 0.0)) - 20.0) < 0.3
	var order_ok = m1.keys() == METRIC_KEYS
	var idle_after = r1.current_state == AISidebarAgentRunner.AgentState.IDLE
	if mismatched.is_empty() and elapsed_ok and order_ok and idle_after:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (metrics mapping) failed: mismatch=%s elapsed=%s order=%s keys=%s" % [str(mismatched), str(elapsed_ok), str(order_ok), str(m1.keys())])

	# 2. Bekleme süresi: beş karar yolu da bekleme süresini biriktirir ve sayacı kapatır
	var waits_ok: Array = []
	# 2a. Netleştirme
	var s2 = _new_runner()
	var r2 = s2["runner"]
	r2.start_task("Soru sor")
	s2["provider"].respond("", [{"id": "c1", "name": "ask_user", "arguments": {"question": "Hangisi?", "options": ["A", "B"]}}])
	var clar_state = r2.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_CLARIFICATION
	_waited(r2, 1200)
	r2.submit_clarification_response("A")
	waits_ok.append(clar_state and _near(r2.waiting_time_msec, 1200) and r2._waiting_start_time == 0)
	# 2b. Plan reddi (görev biter; metrikte de görünür)
	var s3 = _new_runner()
	var r3 = s3["runner"]
	var got3: Array = []
	r3.task_completed.connect(func(m): got3.append(m))
	r3.start_task("Plan sun")
	s3["provider"].respond("", [{"id": "p1", "name": "propose_plan", "arguments": {"goal": "G", "steps": ["a"]}}])
	var plan_state = r3.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL
	_waited(r3, 800)
	r3.reject_plan()
	var m3: Dictionary = got3[0] if got3.size() > 0 else {}
	waits_ok.append(plan_state and _near(r3.waiting_time_msec, 800) and abs(float(m3.get("waiting_time_s", -1.0)) - 0.8) < 0.3)
	# 2c. Plan onayı
	var s4 = _new_runner()
	var r4 = s4["runner"]
	r4.start_task("Plan sun")
	s4["provider"].respond("", [{"id": "p2", "name": "propose_plan", "arguments": {"goal": "G", "steps": ["a"]}}])
	_waited(r4, 600)
	r4.approve_plan()
	waits_ok.append(_near(r4.waiting_time_msec, 600) and r4._waiting_start_time == 0)
	# 2d. Tool onayı reddi
	var s5 = _new_runner()
	var r5 = s5["runner"]
	r5.start_task("Sil")
	s5["provider"].respond("", [{"id": "d1", "name": "delete_node", "arguments": {"node_path": "TempNode"}}])
	var approval_state = r5.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL
	_waited(r5, 900)
	r5.reject_pending_action()
	waits_ok.append(approval_state and _near(r5.waiting_time_msec, 900) and r5._waiting_start_time == 0)
	# 2e. Tool onayı (onaylanan tool'un süresi tool_time'a, adı tool_time_by_name'e yazılır)
	var s6 = _new_runner()
	var r6 = s6["runner"]
	r6.start_task("Sil")
	s6["provider"].respond("", [{"id": "d2", "name": "delete_node", "arguments": {"node_path": "TempNode"}}])
	_waited(r6, 700)
	r6.approve_pending_action()
	waits_ok.append(_near(r6.waiting_time_msec, 700) and r6._waiting_start_time == 0 and r6.tool_time_by_name.has("delete_node") and r6.editor_ops_count == 1 and r6.tool_calls_count == 1)
	if not (false in waits_ok) and waits_ok.size() == 5:
		passed += 1
	else:
		failed += 1
		errors.append("T2 (waiting time per decision path) failed: clar/plan_reject/plan_approve/reject/approve=%s" % str(waits_ok))
	for s in [s2, s4, s5, s6]:
		if s["runner"].is_running():
			s["runner"].stop()

	# 3. LLM süresi: istek başından yanıta kadar geçen süre birikir; her turda llm_turns artar
	var s7 = _new_runner()
	var r7 = s7["runner"]
	r7.start_task("Selam")
	var turns_after_start = r7.llm_turns_count
	r7._llm_step_start_time = Time.get_ticks_msec() - 700
	s7["provider"].respond("Merhaba!")
	var llm_ok = turns_after_start == 1 and _near(r7.llm_time_msec, 700) and r7._llm_step_start_time == 0
	if llm_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (llm time) failed: turns=%d llm=%d start=%d" % [turns_after_start, r7.llm_time_msec, r7._llm_step_start_time])

	# 4. Op sınıflandırması ve kategori süreleri (mevcut eşlemeler olduğu gibi)
	var r8 = AISidebarAgentRunner.new()
	r8._classify_telemetry_op("write_files", {"files": [{}, {}, {}]})
	r8._classify_telemetry_op("write_files", {})
	r8._classify_telemetry_op("replace_file_content", {})
	r8._classify_telemetry_op("delete_node", {})
	r8._classify_telemetry_op("take_runtime_screenshot", {})
	r8._classify_telemetry_op("read_script", {})
	var ops_ok = r8.file_ops_count == 5 and r8.editor_ops_count == 1 and r8.runtime_ops_count == 1
	r8._record_category_time("create_or_update_script", 100)
	r8._record_category_time("write_files", 40)
	r8._record_category_time("replace_file_content", 50)
	r8._record_category_time("delete_file", 60)
	r8._record_category_time("reparent_node", 30)
	r8._record_category_time("get_runtime_errors", 20)
	r8._record_category_time("read_script", 10)
	var cat_ok = r8.file_time_msec == 140 and r8.editor_time_msec == 30 and r8.runtime_time_msec == 20
	if ops_ok and cat_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (op classes + category time) failed: file=%d editor=%d runtime=%d | ft=%d et=%d rt=%d" % [r8.file_ops_count, r8.editor_ops_count, r8.runtime_ops_count, r8.file_time_msec, r8.editor_time_msec, r8.runtime_time_msec])

	# 5. Yeni task telemetriyi sıfırlar (önceki task'ın sayaçları ve süreleri taşınmaz)
	var r9 = r6
	r9.retry_count = 3
	r9.limit_hit = true
	r9.files_read = {"res://x.gd": true}
	r9.research_time_msec = 99
	r9.verification_checkpoints_count = 2
	if r9.is_running():
		r9.stop()
	r9.start_task("Yeni görev")
	var reset_ok = (r9.tool_calls_count == 0 and r9.editor_ops_count == 0 and r9.retry_count == 0
		and not r9.limit_hit and r9.files_read.is_empty() and r9.tool_time_by_name.is_empty()
		and r9.waiting_time_msec == 0 and r9.tool_time_msec == 0 and r9.research_time_msec == 0
		and r9.verification_checkpoints_count == 0 and r9.llm_turns_count == 1
		and Time.get_ticks_msec() - r9.task_start_time_msec < 1000)
	r9.stop()
	if reset_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (reset on new task) failed.")

	return {"name": "AgentTelemetryTests", "passed": passed, "failed": failed, "errors": errors}
