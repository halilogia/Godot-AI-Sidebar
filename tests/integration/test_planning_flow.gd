@tool
extends SceneTree

## UYGULAMA PLANLAMA KATMANI — UCTAN UCA DAVRANIS (ENTEGRASYON) TESTI
##
## SENARYO (kullanicinin istedigi gercek akis):
##   "Create a playable hex grid/map system"
##     request
##       -> clarification            (kritik mimari belirsizlik)
##       -> clarification answer     ("Oynanabilir hex grid")
##       -> mutation denemesi        (plan fazinda ENGELLENMELI)
##       -> implementation plan      (propose_plan)
##       -> plan approval            (Plani Uygula)
##       -> execution                (mevcut agent loop'u)
##       -> verification             (verification pipeline)
##       -> result
##
## NEDEN MOCK KULLANILIYOR:
##   Kullanici acikca "LLM'nin urettigi gercek metne bagli kirilgan testler yazma"
##   dedi. Bu yuzden model yanitlari SABIT bir kuyruktan gelir ve test yalnizca
##   DETERMINISTIK davranislari dogrular:
##     - state gecisleri ve SIRASI
##     - mutation guard (dosya sisteminde GERCEK etki kontrolu)
##     - plan varligi / approval gating
##     - approval SONRASI mevcut execution loop'unun gercekten calismasi
##
## NOT: Gercek production dosyalarina dokunulmaz; probe dosyasi tests/ altinda
## gecici olusturulur ve her durumda temizlenir.

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")

const PROBE_PATH := "res://tests/_tmp_hex_flow_probe.gd"
const PROBE_UID := "res://tests/_tmp_hex_flow_probe.gd.uid"
const USER_REQUEST := "Create a playable hex grid/map system"

class MockFlowProvider extends AISidebarAIProvider:
	var response_queue: Array = []

	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		if response_queue.size() > 0:
			var r = response_queue.pop_front()
			response_received.emit(
				str(r.get("content", "")),
				str(r.get("thinking", "")),
				r.get("tool_calls", [])
			)

static func _cleanup() -> void:
	for p in [PROBE_PATH, PROBE_UID]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

static func _hex_plan_args() -> Dictionary:
	return {
		"goal": "Oynanabilir hex grid sistemi olusturmak.",
		"affected_files": ["res://scripts/HexGrid.gd", "res://scenes/HexMap.tscn"],
		"steps": [
			"HexGrid modelinde axial koordinat donusumu ve komsu aramasi ekle",
			"Grid uretimini ve tile dugumlerini ayri bir sahneye uret",
			"Secim girdisini entegre et",
			"Uretilen dugum hiyerarsisini dogrula"
		],
		"dependencies": ["Godot 4.x"],
		"verification": [
			"Uretilen dugum hiyerarsisini dogrula",
			"Projeyi calistirip hata olmadigini kontrol et"
		],
		"risks": ["Tile sayisi arttikca performans dusebilir"]
	}

func _init() -> void:
	var passed: int = 0
	var failed: int = 0
	var errors: Array = []

	print("")
	print("#################################################################")
	print("#  PLANLAMA AKISI — UCTAN UCA ENTEGRASYON TESTI                 #")
	print("#################################################################")

	var prev_mode = AISidebarPermissionPolicy.get_auto_approve_mode()
	AISidebarPermissionPolicy.set_auto_approve_mode(AISidebarPermissionPolicy.AutoApproveMode.MANUAL)
	_cleanup()

	var prov = MockFlowProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(prov, ctx)

	# --- Gozlemlenebilirlik: durum ve sinyal kayitlari ---
	var timeline: Array = []
	runner.state_changed.connect(func(st, _d):
		timeline.append(AISidebarAgentRunner.AgentState.keys()[st])
	)
	var clar_events: Array = []
	runner.clarification_requested.connect(func(q, opts, cid):
		clar_events.append({"q": q, "opts": opts, "id": cid})
	)
	var plan_events: Array = []
	runner.plan_proposed.connect(func(p): plan_events.append(p))
	var approved_events: Array = []
	runner.plan_approved.connect(func(p): approved_events.append(p))
	var verified_events: Array = []
	runner.verification_completed.connect(func(t, ok, _m): verified_events.append({"tool": t, "ok": ok}))
	# tool_executing YALNIZCA gercekten yurutulen araclar icin yayilir
	# (guard'dan sonra). Bu yuzden "calisti mi?" sorusunun guvenilir kanitidir.
	var executed_tools: Array = []
	runner.tool_executing.connect(func(n, _a): executed_tools.append(n))
	var completed: Array = []
	runner.task_completed.connect(func(m): completed.append(m))

	# ===============================================================
	# [1] REQUEST -> CLARIFICATION
	# ===============================================================
	print("")
	print("  [1] REQUEST: %s" % USER_REQUEST)
	prov.response_queue = [
		{"tool_calls": [{"id": "c_1", "name": "ask_user", "arguments": {
			"question": "Hangi seviyede bir hex sistemi istiyorsunuz?",
			"options": [
				"Tek hexagon objesi",
				"Oynanabilir hex grid",
				"Procedural hex map generator"
			]}}]}
	]
	runner.start_task(USER_REQUEST)

	if runner.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_CLARIFICATION \
		and clar_events.size() == 1 and clar_events[0]["opts"].size() == 3:
		passed += 1
		print("      -> WAITING_FOR_CLARIFICATION (3 secenek)")
	else:
		failed += 1
		errors.append("[1] request->clarification: state=" + str(runner.current_state) + " events=" + str(clar_events.size()))

	# Clarification sirasinda hicbir arac CALISMADI ve plan uretilmedi.
	if executed_tools.is_empty() and plan_events.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("[1b] clarification sirasinda islem yapildi: tools=" + str(executed_tools) + " plans=" + str(plan_events.size()))

	# ===============================================================
	# [2] CLARIFICATION ANSWER -> plan fazinda MUTASYON DENEMESI (engellenmeli)
	# ===============================================================
	print("")
	print("  [2] CLARIFICATION ANSWER: 'Oynanabilir hex grid'")
	print("      (model once dogrudan kod yazmayi deniyor)")
	prov.response_queue = [
		# 2a: Model plan sunmadan kodu yazmaya kalkisiyor -> ENGELLENMELI
		{"tool_calls": [{"id": "m_1", "name": "create_or_update_script", "arguments": {
			"file_path": PROBE_PATH,
			"content": "extends Node\n\n# HexGrid (plansiz yazilmaya calisildi)\n"}}]},
		# 2b: Ardindan plan sunuyor
		{"tool_calls": [{"id": "p_1", "name": "propose_plan", "arguments": _hex_plan_args()}]}
	]
	runner.submit_clarification_response("Oynanabilir hex grid")

	var probe_absent = not FileAccess.file_exists(PROBE_PATH)
	var blocked_msg_in_ctx = false
	for m in ctx.messages:
		if m.get("role") == "tool":
			var parsed = JSON.parse_string(str(m.get("content", "{}")))
			if parsed is Dictionary and parsed.get("error", {}).get("code", "") == "PLAN_PHASE_MUTATION_BLOCKED":
				blocked_msg_in_ctx = true
	if probe_absent and blocked_msg_in_ctx and not "create_or_update_script" in executed_tools:
		passed += 1
		print("      -> MUTASYON ENGELLENDI (dosya yok, arac CALISMADI)")
	else:
		failed += 1
		errors.append("[2] plan fazinda mutation engellenmedi: probe_absent=" + str(probe_absent)
			+ " blocked_in_ctx=" + str(blocked_msg_in_ctx) + " executed=" + str(executed_tools))

	# ===============================================================
	# [3] IMPLEMENTATION PLAN sunuldu ve onay bekleniyor
	# ===============================================================
	print("")
	print("  [3] IMPLEMENTATION PLAN")
	var plan = plan_events[0] if plan_events.size() > 0 else null
	if runner.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_PLAN_APPROVAL \
		and plan != null and plan.is_valid() \
		and plan.steps.size() == 4 and plan.verification.size() == 2 and plan.affected_files.size() == 2:
		passed += 1
		print("      -> WAITING_FOR_PLAN_APPROVAL (4 adim, 2 dogrulama, 2 dosya)")
	else:
		failed += 1
		errors.append("[3] plan sunumu: state=" + str(runner.current_state) + " plan=" + str(plan != null))

	# Plan metni kullaniciya gosterilebilir ve gizli reasoning ICERMEZ.
	var md = plan.to_markdown() if plan != null else ""
	if "## PLAN" in md and "Implementation steps:" in md and "Verification:" in md and "thinking" not in md.to_lower():
		passed += 1
	else:
		failed += 1
		errors.append("[3b] plan markdown artifact gecersiz: " + md.left(80))

	# ===============================================================
	# [4] APPROVAL olmadan execution BASLAMAZ
	# ===============================================================
	print("")
	print("  [4] APPROVAL GATING")
	# Onay oncesi: hicbir arac calismadi. Adim sayisi 3'tur:
	#   1 = ask_user, 2 = engellenen mutation, 3 = propose_plan (plan sunumu).
	if executed_tools.is_empty() and runner.current_step == 3 and not FileAccess.file_exists(PROBE_PATH):
		passed += 1
		print("      -> onay yok, execution YOK (step=%d)" % runner.current_step)
	else:
		failed += 1
		errors.append("[4] approval gating failed: executed=" + str(executed_tools) + " step=" + str(runner.current_step))

	# ===============================================================
	# [5] PLAN APPROVAL -> EXECUTION -> VERIFICATION
	# ===============================================================
	print("")
	print("  [5] PLAN APPROVAL: [Plani Uygula]")
	prov.response_queue = [
		# 5a: gercek mutasyon (artik izinli)
		{"content": "HexGrid dosyasini olusturuyorum.",
			"tool_calls": [{"id": "e_1", "name": "create_or_update_script", "arguments": {
				"file_path": PROBE_PATH,
				"content": "extends Node\n\n## HexGrid — axial koordinat modeli\nfunc _ready() -> void:\n\tpass\n"}}]},
		# 5b: dogrulama adimi (VERIFYING state'ini tetikler)
		{"content": "Uretilen scripti dogruluyorum.",
			"tool_calls": [{"id": "v_1", "name": "validate_script", "arguments": {"file_path": PROBE_PATH}}]},
		# 5c: nihai yanit
		{"content": "Hex grid sistemi olusturuldu ve dogrulandi.", "tool_calls": []}
	]
	runner.approve_plan()

	if approved_events.size() == 1 and not runner._plan_phase_active and runner.pending.plan == null:
		passed += 1
		print("      -> plan onaylandi, plan fazi kapandi")
	else:
		failed += 1
		errors.append("[5] approval: approved=" + str(approved_events.size())
			+ " phase=" + str(runner._plan_phase_active) + " pending=" + str(runner.pending.plan != null))

	if FileAccess.file_exists(PROBE_PATH) and "create_or_update_script" in executed_tools:
		passed += 1
		print("      -> EXECUTION calisti (probe dosyasi olustu)")
	else:
		failed += 1
		errors.append("[5b] execution: file=" + str(FileAccess.file_exists(PROBE_PATH)) + " executed=" + str(executed_tools))

	if verified_events.size() >= 1 and verified_events[0]["tool"] == "validate_script" and verified_events[0]["ok"] == true:
		passed += 1
		print("      -> VERIFICATION calisti (validate_script ok=true)")
	else:
		failed += 1
		errors.append("[5c] verification: " + str(verified_events))

	# ===============================================================
	# [6] RESULT
	# ===============================================================
	print("")
	print("  [6] RESULT")
	if runner.current_state == AISidebarAgentRunner.AgentState.IDLE \
		and completed.size() == 1 and completed[0].get("success", false) == true:
		passed += 1
		print("      -> TASK_COMPLETE (success=true)")
	else:
		failed += 1
		errors.append("[6] result: state=" + str(runner.current_state) + " completed=" + str(completed))

	# ===============================================================
	# [7] DAVRANIS: state SIRASI dogru mu?
	# ===============================================================
	print("")
	print("  [7] DAVRANIS OZETI")
	var i_clar = timeline.find("WAITING_FOR_CLARIFICATION")
	var i_plan = timeline.find("WAITING_FOR_PLAN_APPROVAL")
	var i_verify = timeline.find("VERIFYING")
	var order_ok = (i_clar != -1 and i_plan != -1 and i_verify != -1
		and i_clar < i_plan and i_plan < i_verify)
	if order_ok:
		passed += 1
		print("      -> SIRA DOGRU: clarification(%d) < plan onayi(%d) < dogrulama(%d)" % [i_clar, i_plan, i_verify])
	else:
		failed += 1
		errors.append("[7] state order: timeline=" + str(timeline))

	print("")
	print("  TIMELINE: " + " -> ".join(timeline))
	print("  EXECUTED: " + str(executed_tools))
	print("")

	_cleanup()
	AISidebarPermissionPolicy.set_auto_approve_mode(prev_mode)

	if failed == 0:
		print("  >>> BASARILI: Uctan uca planlama akisi dogrulandi (%d assertion)." % passed)
	else:
		print("  >>> BASARISIZ: %d hata." % failed)
		for e in errors:
			print("      - " + e)
	print("#################################################################")
	print("")
	quit(0 if failed == 0 else 1)
