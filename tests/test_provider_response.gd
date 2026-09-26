@tool
extends RefCounted

## Provider yanıtı işleme hattı (Refactor Faz 2.3 sabitleme testleri). Her dal için gerçek
## AgentRunner'a elle yanıt verilir ve üç şey birebir karşılaştırılır:
##   * sinyal / durum izi (sıra dahil),
##   * context'e yazılan mesajlar (rol, tool adı, çağrı kimliği, hata kodu),
##   * son durum (adım, açılan araçlar, kurtarılmamış hatalar, bekleyen karar).
## Beklenen izler refactor öncesi koddan üretildi. Adım sınırı config'ten okunduğu için
## izlerde " / MAX" olarak normalleştirilir. Ağ ve editör kullanılmaz; okunan dosyalar yoktur.

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

const MISSING = "res://tests/__char_missing__.gd"
## Başarılı yazım senaryosunun oluşturduğu geçici dosya (test sonunda silinir).
const CREATED = "res://tests/__char_created__.gd"

class ManualProvider extends AISidebarAIProvider:
	var sent: int = 0
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		sent += 1
	func respond(text: String, thinking: String = "", tool_calls: Array = []) -> void:
		response_received.emit(text, thinking, tool_calls)

## Runner'ı zayıf referansla tutar: bağlı lambdalar Recorder'ı tuttuğu için güçlü referans
## runner <-> Recorder döngüsü kurar ve ikisi de sızar.
class Recorder extends RefCounted:
	var runner_ref: WeakRef
	var trace: Array = []
	func _init(p_runner) -> void:
		runner_ref = weakref(p_runner)
		var r = p_runner
		r.state_changed.connect(func(s, d): _add("state:" + str(AISidebarAgentRunner.AgentState.keys()[s]) + ":" + str(d)))
		r.thinking_received.connect(func(t): _add("thinking:" + str(t)))
		r.text_received.connect(func(role, t): _add("text:" + str(role) + ":" + str(t)))
		r.tool_executing.connect(func(n, _a): _add("exec:" + str(n)))
		r.tool_completed.connect(func(n, res): _add("done:" + str(n) + ":" + str(bool(res.get("success", false))) + ":" + _code(res)))
		r.approval_requested.connect(func(n, _a, cs): _add("approval:" + str(n) + ":" + str(cs != null)))
		r.clarification_requested.connect(func(q, o, id): _add("clarify:" + str(q) + ":" + str(o) + ":" + str(id)))
		r.plan_proposed.connect(func(p): _add("plan:" + str(p.goal)))
		r.changes_applied.connect(func(_cs): _add("changes"))
		r.verification_started.connect(func(n): _add("verify:" + str(n)))
		r.verification_completed.connect(func(n, v, _m): _add("verified:" + str(n) + ":" + str(v)))
		r.error_occurred.connect(func(m): _add("error:" + str(m)))
		r.loop_finished.connect(func(): _add("loop_finished"))
		r.task_completed.connect(func(m): _add("completed:" + str(m.get("success")) + ":" + str(m.get("completion")) + ":" + str(m.get("completion_reason"))))
		r.step_progress.connect(func(c, _m): _add("step:" + str(c)))
	static func _code(res) -> String:
		var e = res.get("error", null)
		return str(e.get("code", "")) if e is Dictionary else ""
	## Adım sınırı (config) ve arayüz dili (i18n) izden çıkarılır.
	func _add(line: String) -> void:
		var max_steps = str(runner_ref.get_ref().max_steps)
		var out = line.replace(" / " + max_steps, " / MAX").replace("/" + max_steps + ")", "/MAX)")
		for key in ["status_thinking", "status_ready", "agent_stopped"]:
			out = out.replace(AISidebarI18n.get_text(key), "{" + key + "}")
		trace.append(out)

static func _ctx_trace(ctx) -> Array:
	var out: Array = []
	for m in ctx.messages:
		var role = str(m.get("role", ""))
		if role == "tool":
			var res = JSON.parse_string(str(m.get("content", "{}")))
			var code = ""
			if res is Dictionary and res.get("error", null) is Dictionary:
				code = str(res["error"].get("code", ""))
			out.append("tool:" + str(m.get("name", "")) + ":" + str(m.get("tool_call_id", "")) + ":" + code)
		elif role == "assistant" and m.has("tool_calls"):
			var names: Array = []
			for tc in m.get("tool_calls", []):
				names.append(str(tc.get("function", {}).get("name", "")))
			out.append("assistant_calls:" + ",".join(names))
		else:
			out.append(role + ":" + str(m.get("content", "")).left(48))
	return out

## search_tools sonucunda dönen araç adları (araç kaydına bağlı; izde sayıya indirgenir).
static func _searched_names(ctx) -> Array:
	var out: Array = []
	for m in ctx.messages:
		if str(m.get("role", "")) == "tool" and str(m.get("name", "")) == "search_tools":
			var res = JSON.parse_string(str(m.get("content", "{}")))
			if res is Dictionary and res.get("data", null) is Dictionary:
				for t in res["data"].get("tools", []):
					out.append(str(t.get("name", "")))
	return out

static func _snapshot(r, ctx) -> String:
	var searched = _searched_names(ctx)
	var unlocked: Array = []
	var from_search = 0
	for t in r._unlocked_tools:
		if t in searched:
			from_search += 1
		else:
			unlocked.append(t)
	unlocked.sort()
	if not searched.is_empty():
		unlocked.append("<search:%d/%d>" % [from_search, searched.size()])
	var unrec: Array = r.unrecovered_failures.keys()
	unrec.sort()
	var pend = "none"
	if r.pending.has_approval():
		pend = "approval:" + r.pending.tool_name
	elif r.pending.has_clarification():
		pend = "clarification:" + r.pending.clarification_id
	elif r.pending.plan != null:
		pend = "plan:" + r.pending.plan_id
	return "state=%s step=%d unlocked=%s unrecovered=%s pending=%s stagnation=%d empty_retry=%d" % [
		AISidebarAgentRunner.AgentState.keys()[r.current_state], r.current_step, str(unlocked), str(unrec),
		pend, r._stagnation_count, r._empty_response_retry_count]

static func _scenario(name: String, steps: Callable, plan_phase: bool = false) -> Dictionary:
	var p = ManualProvider.new()
	var ctx = AISidebarAgentContext.new()
	var r = AISidebarAgentRunner.new(p, ctx)
	r.enable_planning_gate = false
	var rec = Recorder.new(r)
	r.start_task("Senaryo " + name)
	if plan_phase:
		r._plan_phase_active = true
	steps.call(r, p)
	var out = {"trace": rec.trace.duplicate(), "ctx": _ctx_trace(ctx), "snap": _snapshot(r, ctx), "sent": p.sent}
	if r.is_running():
		r.stop()
	return out

static func _remove_created() -> void:
	for f in [CREATED, CREATED + ".uid"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

static func _call(id: String, name: String, args: Dictionary = {}) -> Dictionary:
	return {"id": id, "name": name, "arguments": args}

## Senaryo adı -> adımlar. Her adım runner ve provider alır.
static func _scenarios() -> Dictionary:
	return {
		"S01_ignored_when_idle": func(r, p):
			r.stop()
			p.respond("geç kalan yanıt"),
		"S02_empty_retry_then_fail": func(r, p):
			p.respond("")
			p.respond(""),
		"S03_empty_retry_then_answer": func(r, p):
			p.respond("")
			p.respond("Tamam.", "düşünce"),
		"S04_text_only_success": func(r, p):
			p.respond("Merhaba!", "selam düşüncesi"),
		"S05_failed_tool_then_text_incomplete": func(r, p):
			p.respond("Okuyorum", "", [_call("a1", "read_script", {"file_path": MISSING})])
			p.respond("Bitti."),
		"S06_stagnation_warning_then_fail": func(r, p):
			p.respond("", "", [_call("b1", "read_script", {"file_path": MISSING})])
			p.respond("", "", [_call("b2", "read_script", {"file_path": MISSING}), _call("b3", "get_project_files", {})])
			p.respond("", "", [_call("b4", "read_script", {"file_path": MISSING})]),
		"S07_clarification_defers_rest": func(r, p):
			p.respond("", "", [_call("c1", "read_script", {"file_path": MISSING}), _call("c2", "ask_user", {"question": "Hangisi?", "options": ["A", 1]}), _call("c3", "get_project_files", {})]),
		"S08_plan_defers_rest": func(r, p):
			p.respond("Plan:", "", [_call("d1", "propose_plan", {"goal": "Zıpla", "steps": ["kod"]}), _call("d2", "read_script", {"file_path": MISSING})]),
		"S09_plan_phase_blocks_mutation": func(r, p):
			p.respond("", "", [_call("e1", "create_or_update_script", {"file_path": "res://tests/__char_blocked__.gd", "content": "extends Node"}), _call("e2", "read_script", {"file_path": MISSING})]),
		"S10_approval_defers_rest": func(r, p):
			p.respond("", "", [_call("f1", "delete_node", {"node_path": "TempNode"}), _call("f2", "read_script", {"file_path": MISSING})]),
		"S11_search_tools_unlocks": func(r, p):
			p.respond("", "", [_call("g1", "search_tools", {"query": "camera"})]),
		"S12_missing_args_and_name": func(r, p):
			p.respond("", "", [{"id": "h1", "name": "ask_user"}]),
		"S13_write_verify_then_success": func(r, p):
			p.respond("", "", [_call("k1", "create_or_update_script", {"file_path": CREATED, "content": "extends Node\n"}), _call("k2", "validate_script", {"file_path": CREATED})])
			p.respond("Yazıldı."),
	}

const EXPECTED = {
	"S01_ignored_when_idle": {
		"trace": [
			"text:user:Senaryo S01_ignored_when_idle",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"state:CANCELLED:{agent_stopped}",
			"error:{agent_stopped}",
			"completed:false:cancelled:Stopped by user.",
			"loop_finished",
			"state:IDLE:{status_ready}",
		],
		"ctx": [
			"user:Senaryo S01_ignored_when_idle",
		],
		"snap": "state=IDLE step=1 unlocked=[] unrecovered=[] pending=none stagnation=0 empty_retry=0",
		"sent": 1,
	},
	"S02_empty_retry_then_fail": {
		"trace": [
			"text:user:Senaryo S02_empty_retry_then_fail",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"state:RECOVERING:Geçici boş yanıt alındı, tekrar deneniyor...",
			"step:2",
			"state:PLANNING:Agent Step 2 / MAX",
			"state:ERROR:Modelden boş yanıt alındı.",
			"error:Model boş yanıt döndürdü (PROVIDER_EMPTY_RESPONSE).",
			"completed:false:failed:Model boş yanıt döndürdü (PROVIDER_EMPTY_RESPONSE).",
			"loop_finished",
			"state:IDLE:{status_ready}",
		],
		"ctx": [
			"user:Senaryo S02_empty_retry_then_fail",
		],
		"snap": "state=IDLE step=2 unlocked=[] unrecovered=[] pending=none stagnation=0 empty_retry=1",
		"sent": 2,
	},
	"S03_empty_retry_then_answer": {
		"trace": [
			"text:user:Senaryo S03_empty_retry_then_answer",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"state:RECOVERING:Geçici boş yanıt alındı, tekrar deneniyor...",
			"step:2",
			"state:PLANNING:Agent Step 2 / MAX",
			"thinking:düşünce",
			"text:assistant:Tamam.",
			"state:COMPLETED:{status_ready}",
			"completed:true:success:Task completed.",
			"loop_finished",
			"state:IDLE:{status_ready}",
		],
		"ctx": [
			"user:Senaryo S03_empty_retry_then_answer",
			"assistant:Tamam.",
		],
		"snap": "state=IDLE step=2 unlocked=[] unrecovered=[] pending=none stagnation=0 empty_retry=0",
		"sent": 2,
	},
	"S04_text_only_success": {
		"trace": [
			"text:user:Senaryo S04_text_only_success",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"thinking:selam düşüncesi",
			"text:assistant:Merhaba!",
			"state:COMPLETED:{status_ready}",
			"completed:true:success:Task completed.",
			"loop_finished",
			"state:IDLE:{status_ready}",
		],
		"ctx": [
			"user:Senaryo S04_text_only_success",
			"assistant:Merhaba!",
		],
		"snap": "state=IDLE step=1 unlocked=[] unrecovered=[] pending=none stagnation=0 empty_retry=0",
		"sent": 1,
	},
	"S05_failed_tool_then_text_incomplete": {
		"trace": [
			"text:user:Senaryo S05_failed_tool_then_text_incomplete",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"text:assistant:Okuyorum",
			"state:EXECUTING:Araç çalıştırılıyor: read_script",
			"exec:read_script",
			"done:read_script:false:FILE_NOT_FOUND",
			"state:OBSERVING:Sonuçlar analiz ediliyor...",
			"step:2",
			"state:PLANNING:Agent Step 2 / MAX",
			"text:assistant:Bitti.",
			"state:ERROR:Unresolved work (failed tool(s) without recovery: read_script).",
			"error:Unresolved work (failed tool(s) without recovery: read_script).",
			"completed:false:incomplete:Unresolved work (failed tool(s) without recovery: read_script).",
			"loop_finished",
			"state:IDLE:{status_ready}",
		],
		"ctx": [
			"user:Senaryo S05_failed_tool_then_text_incomplete",
			"assistant_calls:read_script",
			"tool:read_script:a1:FILE_NOT_FOUND",
			"assistant:Bitti.",
		],
		"snap": "state=IDLE step=2 unlocked=[\"read_script\"] unrecovered=[\"read_script|res://tests/__char_missing__.gd\"] pending=none stagnation=0 empty_retry=0",
		"sent": 2,
	},
	"S06_stagnation_warning_then_fail": {
		"trace": [
			"text:user:Senaryo S06_stagnation_warning_then_fail",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"state:EXECUTING:Araç çalıştırılıyor: read_script",
			"exec:read_script",
			"done:read_script:false:FILE_NOT_FOUND",
			"state:OBSERVING:Sonuçlar analiz ediliyor...",
			"step:2",
			"state:PLANNING:Agent Step 2 / MAX",
			"done:get_project_files:false:DEFERRED_AFTER_STAGNATION_WARNING",
			"step:3",
			"state:PLANNING:Agent Step 3 / MAX",
			"state:ERROR:Aynı araç (read_script) tekrar tekrar çağrıldı.",
			"error:Ajan aynı aracı (read_script) tekrarladı. Görev sonlandırıldı.",
			"completed:false:failed:Ajan aynı aracı (read_script) tekrarladı.",
			"loop_finished",
			"state:IDLE:{status_ready}",
		],
		"ctx": [
			"user:Senaryo S06_stagnation_warning_then_fail",
			"assistant_calls:read_script",
			"tool:read_script:b1:FILE_NOT_FOUND",
			"assistant_calls:read_script,get_project_files",
			"user:SİSTEM BİLGİSİ: 'read_script' aracı zaten çalışt",
			"tool:read_script:b2:DUPLICATE_CALL",
			"tool:get_project_files:b3:DEFERRED_AFTER_STAGNATION_WARNING",
			"assistant_calls:read_script",
		],
		"snap": "state=IDLE step=3 unlocked=[\"read_script\"] unrecovered=[\"get_project_files|\", \"read_script|res://tests/__char_missing__.gd\"] pending=none stagnation=2 empty_retry=0",
		"sent": 3,
	},
	"S07_clarification_defers_rest": {
		"trace": [
			"text:user:Senaryo S07_clarification_defers_rest",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"state:EXECUTING:Araç çalıştırılıyor: read_script",
			"exec:read_script",
			"done:read_script:false:FILE_NOT_FOUND",
			"state:OBSERVING:Sonuçlar analiz ediliyor...",
			"state:WAITING_FOR_CLARIFICATION:Kullanıcıdan yanıt bekleniyor...",
			"done:get_project_files:false:DEFERRED_FOR_CLARIFICATION",
			"clarify:Hangisi?:[\"A\", \"1\"]:c2",
		],
		"ctx": [
			"user:Senaryo S07_clarification_defers_rest",
			"assistant_calls:read_script,ask_user,get_project_files",
			"tool:read_script:c1:FILE_NOT_FOUND",
			"tool:get_project_files:c3:DEFERRED_FOR_CLARIFICATION",
		],
		"snap": "state=WAITING_FOR_CLARIFICATION step=1 unlocked=[\"ask_user\", \"read_script\"] unrecovered=[\"get_project_files|\", \"read_script|res://tests/__char_missing__.gd\"] pending=clarification:c2 stagnation=0 empty_retry=0",
		"sent": 1,
	},
	"S08_plan_defers_rest": {
		"trace": [
			"text:user:Senaryo S08_plan_defers_rest",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"text:assistant:Plan:",
			"state:WAITING_FOR_PLAN_APPROVAL:Plan onayı bekleniyor...",
			"done:read_script:false:DEFERRED_FOR_PLAN",
			"plan:Zıpla",
		],
		"ctx": [
			"user:Senaryo S08_plan_defers_rest",
			"assistant_calls:propose_plan,read_script",
			"tool:read_script:d2:DEFERRED_FOR_PLAN",
		],
		"snap": "state=WAITING_FOR_PLAN_APPROVAL step=1 unlocked=[\"propose_plan\"] unrecovered=[\"read_script|res://tests/__char_missing__.gd\"] pending=plan:d1 stagnation=0 empty_retry=0",
		"sent": 1,
	},
	"S09_plan_phase_blocks_mutation": {
		"trace": [
			"text:user:Senaryo S09_plan_phase_blocks_mutation",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"state:EXECUTING:Araç çalıştırılıyor: read_script",
			"exec:read_script",
			"done:read_script:false:FILE_NOT_FOUND",
			"state:OBSERVING:Sonuçlar analiz ediliyor...",
			"step:2",
			"state:PLANNING:Agent Step 2 / MAX",
		],
		"ctx": [
			"user:Senaryo S09_plan_phase_blocks_mutation",
			"assistant_calls:create_or_update_script,read_script",
			"tool:create_or_update_script:e1:PLAN_PHASE_MUTATION_BLOCKED",
			"tool:read_script:e2:FILE_NOT_FOUND",
		],
		"snap": "state=PLANNING step=2 unlocked=[\"create_or_update_script\", \"read_script\"] unrecovered=[\"read_script|res://tests/__char_missing__.gd\"] pending=none stagnation=0 empty_retry=0",
		"sent": 2,
	},
	"S10_approval_defers_rest": {
		"trace": [
			"text:user:Senaryo S10_approval_defers_rest",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"state:EXECUTING:Araç çalıştırılıyor: delete_node",
			"exec:delete_node",
			"state:WAITING_FOR_APPROVAL:Kullanıcı onayı bekleniyor (delete_node)",
			"done:read_script:false:DEFERRED_FOR_APPROVAL",
			"approval:delete_node:true",
		],
		"ctx": [
			"user:Senaryo S10_approval_defers_rest",
			"assistant_calls:delete_node,read_script",
			"tool:read_script:f2:DEFERRED_FOR_APPROVAL",
		],
		"snap": "state=WAITING_FOR_APPROVAL step=1 unlocked=[\"delete_node\"] unrecovered=[\"read_script|res://tests/__char_missing__.gd\"] pending=approval:delete_node stagnation=0 empty_retry=0",
		"sent": 1,
	},
	"S11_search_tools_unlocks": {
		"trace": [
			"text:user:Senaryo S11_search_tools_unlocks",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"state:EXECUTING:Araç çalıştırılıyor: search_tools",
			"exec:search_tools",
			"done:search_tools:true:",
			"state:OBSERVING:Sonuçlar analiz ediliyor...",
			"step:2",
			"state:PLANNING:Agent Step 2 / MAX",
		],
		"ctx": [
			"user:Senaryo S11_search_tools_unlocks",
			"assistant_calls:search_tools",
			"tool:search_tools:g1:",
		],
		"snap": "state=PLANNING step=2 unlocked=[\"search_tools\", \"<search:3/3>\"] unrecovered=[] pending=none stagnation=0 empty_retry=0",
		"sent": 2,
	},
	"S12_missing_args_and_name": {
		"trace": [
			"text:user:Senaryo S12_missing_args_and_name",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"state:WAITING_FOR_CLARIFICATION:Kullanıcıdan yanıt bekleniyor...",
			"clarify:Lütfen seçiminizi belirtin.:[]:h1",
		],
		"ctx": [
			"user:Senaryo S12_missing_args_and_name",
			"assistant_calls:ask_user",
		],
		"snap": "state=WAITING_FOR_CLARIFICATION step=1 unlocked=[\"ask_user\"] unrecovered=[] pending=clarification:h1 stagnation=0 empty_retry=0",
		"sent": 1,
	},
	"S13_write_verify_then_success": {
		"trace": [
			"text:user:Senaryo S13_write_verify_then_success",
			"state:PLANNING:{status_thinking}",
			"step:1",
			"state:PLANNING:Agent Step 1 / MAX",
			"state:EXECUTING:Araç çalıştırılıyor: create_or_update_script",
			"exec:create_or_update_script",
			"done:create_or_update_script:true:",
			"changes",
			"state:OBSERVING:Sonuçlar analiz ediliyor...",
			"state:EXECUTING:Araç çalıştırılıyor: validate_script",
			"exec:validate_script",
			"done:validate_script:true:",
			"state:VERIFYING:Doğrulanıyor: validate_script",
			"verify:validate_script",
			"verified:validate_script:true",
			"state:OBSERVING:Sonuçlar analiz ediliyor...",
			"step:2",
			"state:PLANNING:Agent Step 2 / MAX",
			"text:assistant:Yazıldı.",
			"state:COMPLETED:{status_ready}",
			"completed:true:success:Task completed.",
			"loop_finished",
			"state:IDLE:{status_ready}",
		],
		"ctx": [
			"user:Senaryo S13_write_verify_then_success",
			"assistant_calls:create_or_update_script,validate_script",
			"tool:create_or_update_script:k1:",
			"tool:validate_script:k2:",
			"assistant:Yazıldı.",
		],
		"snap": "state=IDLE step=2 unlocked=[\"create_or_update_script\", \"validate_script\"] unrecovered=[] pending=none stagnation=0 empty_retry=0",
		"sent": 2,
	},
}

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	var scenarios = _scenarios()
	var names: Array = scenarios.keys()
	names.sort()
	_remove_created()
	for name in names:
		var plan_phase = name == "S09_plan_phase_blocks_mutation"
		var got = _scenario(name, scenarios[name], plan_phase)
		var want = EXPECTED.get(name, {})
		if not want.is_empty() and got["trace"] == want["trace"] and got["ctx"] == want["ctx"] and got["snap"] == want["snap"] and got["sent"] == want["sent"]:
			passed += 1
		else:
			failed += 1
			errors.append("%s differs:\n      got  %s" % [name, JSON.stringify(got)])
			if not want.is_empty():
				errors.append("%s want %s" % [name, JSON.stringify(want)])
	if FileAccess.file_exists("res://tests/__char_blocked__.gd"):
		failed += 1
		errors.append("Plan fazında engellenen yazım diske ulaştı.")
	_remove_created()
	return {"name": "ProviderResponseTests", "passed": passed, "failed": failed, "errors": errors}
