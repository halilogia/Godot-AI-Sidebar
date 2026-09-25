@tool
extends RefCounted

## UYGULAMA PLANLAMA KATMANI — DETERMINISTIK TESTLER
##
## NEDEN DETERMINISTIK:
##   Kullanıcı "LLM'nin ürettiği gerçek metne bağımlı kırılgan testler yazma;
##   state transition, mutation guard, plan presence ve approval gating gibi
##   deterministik davranışları test et" dedi.
##   Bu yüzden tüm testler MockProvider kullanır ve yalnızca
##   durum geçişleri, guard davranışı ve dosya sistemi üzerindeki
##   GERÇEK etkileri doğrular.

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarPlanningPolicy = preload("res://addons/godot_sidebar_ai/core/agent/planning_policy.gd")
const AISidebarImplementationPlan = preload("res://addons/godot_sidebar_ai/core/types/implementation_plan.gd")
const AISidebarPlanCard = preload("res://addons/godot_sidebar_ai/ui/components/plan_card.gd")

## Test sırasında mutasyon denemesi için kullanılan geçici dosya.
## Guard çalışıyorsa bu dosya ASLA oluşmamalıdır.
const GUARD_PROBE_PATH := "res://tests/_tmp_plan_guard_probe.gd"

class MockPlanProvider extends AISidebarAIProvider:
	var response_queue: Array = []
	var recorded_requests: Array = []

	func send_chat(messages: Array, tools_schema: Array) -> void:
		recorded_requests.append({"messages": messages.duplicate(true), "tools": tools_schema.duplicate(true)})
		if response_queue.size() > 0:
			var r = response_queue.pop_front()
			var content_txt = str(r.get("content", ""))
			var thinking_txt = str(r.get("thinking", ""))
			var tool_calls = r.get("tool_calls", [])
			if not thinking_txt.is_empty():
				chunk_received.emit("", thinking_txt)
			if not content_txt.is_empty():
				chunk_received.emit(content_txt, "")
			response_received.emit(content_txt, thinking_txt, tool_calls)

## Geçerli, kabul edilebilir bir plan argüman seti üretir.
static func _valid_plan_args() -> Dictionary:
	return {
		"goal": "Oynanabilir hex grid sistemi oluşturmak.",
		"affected_files": ["res://scripts/HexGrid.gd", "res://scenes/HexMap.tscn"],
		"steps": [
			"HexGrid modelinde axial koordinat dönüşümü ve komşu araması ekle",
			"Grid üretimini ve tile düğümlerini ayrı bir sahneye üret",
			"Seçim girdisini entegre et",
			"Üretilen düğüm hiyerarşisini doğrula"
		],
		"dependencies": ["Godot 4.x"],
		"verification": [
			"Üretilen düğüm hiyerarşisini doğrula",
			"Projeyi çalıştırıp hata olmadığını kontrol et"
		],
		"risks": ["Tile sayısı arttıkça performans düşebilir"]
	}

## Belirli tool_call id'ye ait tool sonuç mesajını context'ten bulur.
static func _find_tool_result(ctx, call_id: String) -> Dictionary:
	for m in ctx.messages:
		if m is Dictionary and str(m.get("role", "")) == "tool" and str(m.get("tool_call_id", "")) == call_id:
			var parsed = JSON.parse_string(str(m.get("content", "{}")))
			if parsed is Dictionary:
				return parsed
	return {}

static func _cleanup_probe_file() -> void:
	if FileAccess.file_exists(GUARD_PROBE_PATH):
		DirAccess.remove_absolute(GUARD_PROBE_PATH)
	var uid_path := GUARD_PROBE_PATH + ".uid"
	if FileAccess.file_exists(uid_path):
		DirAccess.remove_absolute(uid_path)

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	var prev_mode = AISidebarPermissionPolicy.get_auto_approve_mode()
	AISidebarPermissionPolicy.set_auto_approve_mode(AISidebarPermissionPolicy.AutoApproveMode.MANUAL)
	_cleanup_probe_file()

	# --- Kapsam Sınıflandırıcı (deterministik, LLM'siz) ---
	var plan_required = [
		"Bir hexagon map sistemi oluştur.",
		"Oyuncu ve inventory sistemi oluştur",
		"Enemy AI ekle",
		"Quest sistemi oluştur",
		"Main menu yap",
		"Save/load sistemi ekle",
		"Procedural dungeon generator oluştur",
		"Create a playable hex grid/map system"
	]
	var plan_forbidden = [
		"Player'ın speed değerini 300 yap",
		"health değerini 100 yap.",
		"Projenin ana sahnesinin adını söyle",
		"Selam"
	]

	# Test 1: Buyuk/kapsamli istekler plan GEREKTIRIR
	var classifier_ok = true
	var classifier_err = ""
	for p in plan_required:
		if not AISidebarPlanningPolicy.should_plan(p):
			classifier_ok = false
			classifier_err = "Plan gerekli ama should_plan=false: " + p
	if classifier_ok:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (large_request_requires_plan) failed: " + classifier_err)

	# Test 2: Trivial/tekil istekler plan GEREKTIRMEZ (planning threshold)
	var skip_ok = true
	var skip_err = ""
	for p in plan_forbidden:
		if AISidebarPlanningPolicy.should_plan(p):
			skip_ok = false
			skip_err = "Plan gereksiz ama should_plan=true: " + p
	if skip_ok:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (trivial_request_skips_plan) failed: " + skip_err)

	# --- SENARYO 1: Buyuk istek -> plan olusturulur (propose_plan intercept) ---
	var mock1 = MockPlanProvider.new()
	var ctx1 = AISidebarAgentContext.new()
	var runner1 = AISidebarAgentRunner.new(mock1, ctx1)
	var caught1 = {"plan": null, "count": 0}
	runner1.plan_proposed.connect(func(p):
		caught1["plan"] = p
		caught1["count"] += 1
	)
	var mutations1 = []
	runner1.tool_executing.connect(func(n, _a): mutations1.append(n))

	mock1.response_queue = [
		{"tool_calls": [{"id": "p1", "name": "propose_plan", "arguments": _valid_plan_args()}]},
		{"content": "onaylandi", "tool_calls": []}
	]
	runner1.start_task("Bir hexagon map sistemi oluştur.")

	var is_waiting_plan = (runner1.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL)
	var plan_ok = caught1["plan"] != null and caught1["plan"].steps.size() == 4 and caught1["plan"].verification.size() == 2
	# propose_plan bir tool olarak ÇALIŞTIRILMAMALIDIR (intercept edilir).
	if is_waiting_plan and caught1["count"] == 1 and plan_ok and mutations1.is_empty() and runner1._plan_phase_active:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (scenario_1_plan_created) failed: state=" + str(runner1.current_state) + " count=" + str(caught1["count"]) + " mutations=" + str(mutations1))

	# --- SENARYO 5: Plan approval olmadan execution BASLAMAZ ---
	# Ayni runner hala WAITING_FOR_PLAN_APPROVAL durumunda; hicbir arac calismadi.
	if runner1.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL and mutations1.is_empty() and runner1.current_step == 1:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (scenario_5_no_execution_without_approval) failed: state=" + str(runner1.current_state) + " step=" + str(runner1.current_step))

	# --- SENARYO 6: Plan approval sonrasi mevcut execution loop calisir ---
	runner1.approve_plan()
	var is_completed = (runner1.current_state == AISidebarAgentRunner.AgentState.IDLE or runner1.current_state == AISidebarAgentRunner.AgentState.COMPLETED)
	if is_completed and not runner1._plan_phase_active and runner1.pending.plan == null:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (scenario_6_execution_after_approval) failed: state=" + str(runner1.current_state) + " plan_phase=" + str(runner1._plan_phase_active))

	# --- SENARYO 6b: Approval, propose_plan çağrısına eşleşen tool sonucu yazar ---
	# (Katı gateway'ler her tool_call id için sonuç ister; yoksa 503 reddeder.)
	var approved_res = _find_tool_result(ctx1, "p1")
	if not approved_res.is_empty() and bool(approved_res.get("success", false)):
		passed += 1
	else:
		failed += 1
		errors.append("Test 5b (approval_writes_tool_result) failed: " + str(approved_res).left(160))

	# --- SENARYO 4: Plan asamasinda mutation GERCEKLESMEZ ---
	var mock4 = MockPlanProvider.new()
	var ctx4 = AISidebarAgentContext.new()
	var runner4 = AISidebarAgentRunner.new(mock4, ctx4)
	mock4.response_queue = [
		{"tool_calls": [{"id": "m1", "name": "create_or_update_script", "arguments": {
			"file_path": GUARD_PROBE_PATH, "content": "extends Node\n"}}]},
		{"content": "tamam", "tool_calls": []}
	]
	runner4.start_task("Bir inventory sistemi oluştur.")  # plan fazi aktif

	var blocked_in_ctx = false
	for m in ctx4.messages:
		if m.get("role") == "tool":
			var c = JSON.parse_string(str(m.get("content", "{}")))
			if c is Dictionary and c.get("error", {}).get("code", "") == "PLAN_PHASE_MUTATION_BLOCKED":
				blocked_in_ctx = true
	var file_not_created = not FileAccess.file_exists(GUARD_PROBE_PATH)
	if blocked_in_ctx and file_not_created:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (scenario_4_no_mutation_during_plan) failed: blocked_in_ctx=" + str(blocked_in_ctx) + " file_created=" + str(not file_not_created))

	# --- SENARYO 7: Trivial istek plan asamasini ATLAR ---
	var mock7 = MockPlanProvider.new()
	var ctx7 = AISidebarAgentContext.new()
	var runner7 = AISidebarAgentRunner.new(mock7, ctx7)
	var plan_fired7 = [false]
	runner7.plan_proposed.connect(func(_p): plan_fired7[0] = true)
	mock7.response_queue = [{"content": "Speed 300 yapıldı.", "tool_calls": []}]
	runner7.start_task("Player'ın speed değerini 300 yap")

	if not plan_fired7[0] and not runner7._plan_phase_active and (runner7.current_state == AISidebarAgentRunner.AgentState.IDLE or runner7.current_state == AISidebarAgentRunner.AgentState.COMPLETED):
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (scenario_7_trivial_skips_plan) failed: plan_fired=" + str(plan_fired7[0]) + " active=" + str(runner7._plan_phase_active) + " state=" + str(runner7.current_state))

	# --- SENARYO 8: Plan iptali HICBIR mutation uretmez ---
	var mock8 = MockPlanProvider.new()
	var ctx8 = AISidebarAgentContext.new()
	var runner8 = AISidebarAgentRunner.new(mock8, ctx8)
	var rejected8 = [false]
	runner8.plan_rejected.connect(func(_p): rejected8[0] = true)
	mock8.response_queue = [
		{"tool_calls": [{"id": "p8", "name": "propose_plan", "arguments": _valid_plan_args()}]},
		{"tool_calls": [{"id": "m8", "name": "create_or_update_script", "arguments": {
			"file_path": GUARD_PROBE_PATH, "content": "extends Node\n"}}]}
	]
	runner8.start_task("Bir quest sistemi oluştur.")
	var was_waiting = (runner8.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL)
	runner8.reject_plan()

	var cancelled_ok = (runner8.current_state == AISidebarAgentRunner.AgentState.IDLE or runner8.current_state == AISidebarAgentRunner.AgentState.CANCELLED)
	var file_still_absent = not FileAccess.file_exists(GUARD_PROBE_PATH)
	if was_waiting and rejected8[0] and cancelled_ok and file_still_absent and not runner8._plan_phase_active:
		passed += 1
	else:
		failed += 1
		errors.append("Test 8 (scenario_8_cancel_no_mutation) failed: waiting=" + str(was_waiting) + " rejected=" + str(rejected8[0]) + " state=" + str(runner8.current_state) + " file=" + str(not file_still_absent))

	# --- SENARYO 8b: Reject de propose_plan çağrısına eşleşen sonuç yazar ---
	var rejected_res = _find_tool_result(ctx8, "p8")
	if not rejected_res.is_empty() and not bool(rejected_res.get("success", true)) and str(rejected_res.get("error", {}).get("code", "")) == "PLAN_REJECTED":
		passed += 1
	else:
		failed += 1
		errors.append("Test 8b (reject_writes_tool_result) failed: " + str(rejected_res).left(160))

	# --- SENARYO 2: Kritik ambiguity -> mevcut ask_user calisir (plan fazinda da) ---
	var mock2 = MockPlanProvider.new()
	var ctx2 = AISidebarAgentContext.new()
	var runner2 = AISidebarAgentRunner.new(mock2, ctx2)
	var caught2 = {"q": "", "opts": []}
	runner2.clarification_requested.connect(func(q, opts, _cid):
		caught2["q"] = q
		caught2["opts"] = opts
	)
	mock2.response_queue = [
		{"tool_calls": [{"id": "c2", "name": "ask_user", "arguments": {
			"question": "Hangisini istiyorsunuz?",
			"options": ["Tek hexagon objesi", "Oynanabilir hex grid", "Procedural hex map generator"]}}]}
	]
	runner2.start_task("Bir hexagon map sistemi oluştur.")

	var clar_state_ok = (runner2.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_CLARIFICATION)
	var opts_ok = (caught2["opts"].size() == 3)
	if clar_state_ok and opts_ok and caught2["q"] == "Hangisini istiyorsunuz?":
		passed += 1
	else:
		failed += 1
		errors.append("Test 9 (scenario_2_clarification_in_plan_phase) failed: state=" + str(runner2.current_state) + " opts=" + str(caught2["opts"]))

	# --- SENARYO 3: Clarification cevabindan sonra plan olusturulur ---
	var plan_after_clar = [null]
	runner2.plan_proposed.connect(func(p): plan_after_clar[0] = p)
	mock2.response_queue = [
		{"tool_calls": [{"id": "p2", "name": "propose_plan", "arguments": _valid_plan_args()}]},
		{"content": "bitti", "tool_calls": []}
	]
	runner2.submit_clarification_response("Oynanabilir hex grid")

	var plan_sequence_ok = (plan_after_clar[0] != null and runner2.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL and runner2.current_step == 2)
	if plan_sequence_ok:
		passed += 1
	else:
		failed += 1
		errors.append("Test 10 (scenario_3_plan_after_clarification) failed: plan=" + str(plan_after_clar[0] != null) + " step=" + str(runner2.current_step))

	# --- Test 11: Plan fazinda mutation araclari sema olarak SUNULMAZ ---
	var plan_schemas = AISidebarToolManager.get_relevant_schemas("inventory sistem oluştur", [], true)
	var names_ro: Array = []
	for s in plan_schemas:
		names_ro.append(s.get("function", {}).get("name", ""))
	var leaks: Array = []
	for n in names_ro:
		if AISidebarPlanningPolicy.is_mutation_blocked(str(n)):
			leaks.append(str(n))
	if leaks.is_empty() and "propose_plan" in names_ro and "ask_user" in names_ro:
		passed += 1
	else:
		failed += 1
		errors.append("Test 11 (read_only_schema_filter) failed: leaks=" + str(leaks) + " count=" + str(names_ro.size()))

	# --- Test 12: Normal modda (read_only_only=false) mutation araclari SUNULUR ---
	var normal_schemas = AISidebarToolManager.get_relevant_schemas("inventory sistem oluştur", [], false)
	var normal_names: Array = []
	for s in normal_schemas:
		normal_names.append(s.get("function", {}).get("name", ""))
	if "create_or_update_script" in normal_names and "propose_plan" in normal_names:
		passed += 1
	else:
		failed += 1
		errors.append("Test 12 (normal_mode_full_schemas) failed: count=" + str(normal_names.size()))

	# --- Test 13: propose_plan semasi kayitli ve READ_ONLY riskli ---
	var all_schemas = AISidebarToolManager.get_all_schemas()
	var has_plan_schema = false
	for s in all_schemas:
		if s.get("function", {}).get("name", "") == "propose_plan":
			has_plan_schema = true
			break
	var risk_ok = (AISidebarPermissionPolicy.get_tool_risk("propose_plan") == AISidebarPermissionPolicy.RiskLevel.READ_ONLY)
	if has_plan_schema and risk_ok:
		passed += 1
	else:
		failed += 1
		errors.append("Test 13 (propose_plan schema & risk) failed: schema=" + str(has_plan_schema) + " risk=" + str(AISidebarPermissionPolicy.get_tool_risk("propose_plan")))

	# --- Test 14: propose_plan execute_tool hicbir mutasyon yapmaz ---
	var plan_exec = AISidebarToolManager.execute_tool("propose_plan", _valid_plan_args())
	if plan_exec.get("success", false) and plan_exec.get("data", {}).get("plan", false) and not FileAccess.file_exists(GUARD_PROBE_PATH):
		passed += 1
	else:
		failed += 1
		errors.append("Test 14 (propose_plan execution is inert) failed: " + str(plan_exec))

	# --- Test 15: ImplementationPlan gecersiz plan tespiti ---
	var invalid_plan = AISidebarImplementationPlan.new({"goal": "sadece amac"})
	var valid_plan = AISidebarImplementationPlan.new(_valid_plan_args())
	if not invalid_plan.is_valid() and valid_plan.is_valid():
		passed += 1
	else:
		failed += 1
		errors.append("Test 15 (plan validity) failed: invalid=" + str(invalid_plan.is_valid()) + " valid=" + str(valid_plan.is_valid()))

	# --- Test 16: to_markdown kullaniciya gosterilebilir artifact uretir ---
	var md = valid_plan.to_markdown()
	var md_ok = ("## PLAN" in md and "Goal:" in md and "Affected files:" in md
		and "Implementation steps:" in md and "Verification:" in md
		and "HexGrid.gd" in md and "1. " in md)
	if md_ok:
		passed += 1
	else:
		failed += 1
		errors.append("Test 16 (plan markdown artifact) failed: " + md.left(120))

	# --- Test 17: enable_planning_gate = false eski hizli davranisi korur ---
	var mock17 = MockPlanProvider.new()
	var ctx17 = AISidebarAgentContext.new()
	var runner17 = AISidebarAgentRunner.new(mock17, ctx17)
	runner17.enable_planning_gate = false
	mock17.response_queue = [{"content": "yapildi", "tool_calls": []}]
	runner17.start_task("Bir inventory sistemi oluştur.")  # normalde plan gerektirir
	if not runner17._plan_phase_active and (runner17.current_state == AISidebarAgentRunner.AgentState.IDLE or runner17.current_state == AISidebarAgentRunner.AgentState.COMPLETED):
		passed += 1
	else:
		failed += 1
		errors.append("Test 17 (planning gate disable) failed: active=" + str(runner17._plan_phase_active) + " state=" + str(runner17.current_state))

	# --- Test 18: PlanCard UI [Planı Uygula] / [İptal] akisi ---
	var card = AISidebarPlanCard.new(valid_plan)
	card._ready()
	var applied = [false]
	var cancelled = [false]
	card.plan_applied.connect(func(): applied[0] = true)
	card.plan_cancelled.connect(func(): cancelled[0] = true)
	card._on_apply()
	var apply_ok = (applied[0] and card.is_resolved and not card._apply_btn.visible and not card._cancel_btn.visible)
	card._on_cancel() # is_resolved oldugu icin ikinci kez tetiklenmemeli
	var double_ok = (not cancelled[0])
	card.queue_free()
	if apply_ok and double_ok:
		passed += 1
	else:
		failed += 1
		errors.append("Test 18 (plan card apply/cancel) failed: applied=" + str(applied[0]) + " cancelled=" + str(cancelled[0]))

	# --- Test 19: PlanCard iptal akisi ---
	var card2 = AISidebarPlanCard.new(valid_plan)
	card2._ready()
	var cancelled2 = [false]
	card2.plan_cancelled.connect(func(): cancelled2[0] = true)
	card2._on_cancel()
	if cancelled2[0] and card2.is_resolved and not card2._apply_btn.visible:
		passed += 1
	else:
		failed += 1
		errors.append("Test 19 (plan card cancel) failed")
	card2.queue_free()

	# --- Test 20: Mutation guard tablosu (fail-closed) ---
	var guard_expect = {
		"create_or_update_script": true, "write_files": true, "delete_file": true,
		"delete_node": true, "create_scene": true, "add_node": true,
		"set_node_property": true, "create_character_scene": true, "play_game": true,
		"bilinmeyen_mutasyon_araci": true,
		"ask_user": false, "propose_plan": false, "read_script": false,
		"analyze_project": false, "search_tools": false, "validate_script": false
	}
	var guard_ok = true
	var guard_err = ""
	for tool in guard_expect.keys():
		var expected: bool = guard_expect[tool]
		var actual: bool = AISidebarPlanningPolicy.is_mutation_blocked(tool)
		if expected != actual:
			guard_ok = false
			guard_err = tool + " beklenen=" + str(expected) + " gercek=" + str(actual)
	if guard_ok:
		passed += 1
	else:
		failed += 1
		errors.append("Test 20 (mutation guard table) failed: " + guard_err)

	# --- Test 21: stop() plan durumunu temizler (mutation yok) ---
	var mock21 = MockPlanProvider.new()
	var ctx21 = AISidebarAgentContext.new()
	var runner21 = AISidebarAgentRunner.new(mock21, ctx21)
	mock21.response_queue = [{"tool_calls": [{"id": "p21", "name": "propose_plan", "arguments": _valid_plan_args()}]}]
	runner21.start_task("Bir save/load sistemi ekle")
	runner21.stop()
	if runner21.current_state == AISidebarAgentRunner.AgentState.IDLE and runner21.pending.plan == null and not runner21._plan_phase_active:
		passed += 1
	else:
		failed += 1
		errors.append("Test 21 (stop clears plan state) failed: state=" + str(runner21.current_state))

	# --- Test 22: Engellenen arac telemetride 'yapilmis is' olarak SAYILMAZ ---
	# Regresyon kilidi: telemetri siniflandirmasi guard'dan ONCE calisirsa,
	# hic yurutulmeyen bir yazma islemi file_ops olarak sayilir ve metrikler yanlis olur.
	var mock22 = MockPlanProvider.new()
	var ctx22 = AISidebarAgentContext.new()
	var runner22 = AISidebarAgentRunner.new(mock22, ctx22)
	mock22.response_queue = [
		{"tool_calls": [{"id": "t22", "name": "write_files", "arguments": {
			"files": [{"file_path": GUARD_PROBE_PATH, "content": "extends Node\n"}]}}]},
		{"content": "tamam", "tool_calls": []}
	]
	runner22.start_task("Bir save/load sistemi ekle")
	var probe_absent = not FileAccess.file_exists(GUARD_PROBE_PATH)
	if runner22.telemetry.file_ops_count == 0 and runner22.telemetry.tool_calls_count == 1 and probe_absent:
		passed += 1
	else:
		failed += 1
		errors.append("Test 22 (blocked tool not counted) failed: file_ops=" + str(runner22.telemetry.file_ops_count) + " tool_calls=" + str(runner22.telemetry.tool_calls_count) + " probe_absent=" + str(probe_absent))

	_cleanup_probe_file()
	AISidebarPermissionPolicy.set_auto_approve_mode(prev_mode)
	return {"name": "ImplementationPlanningTests", "passed": passed, "failed": failed, "errors": errors}
