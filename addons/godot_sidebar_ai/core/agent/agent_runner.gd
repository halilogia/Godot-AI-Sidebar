@tool
extends RefCounted
class_name AISidebarAgentRunner

## Otonom Ajan İcra Döngüsü, Hata Ayıklama & Detaylı Zaman/Telemetri Motoru (SRP).

const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarRuntimeDebugger = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_debugger.gd")
const AISidebarVisionInput = preload("res://addons/godot_sidebar_ai/core/types/vision_input.gd")
const AISidebarPlanningPolicy = preload("res://addons/godot_sidebar_ai/core/agent/planning_policy.gd")
const AISidebarImplementationPlan = preload("res://addons/godot_sidebar_ai/core/types/implementation_plan.gd")
const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")

enum AgentState {
	IDLE,
	PLANNING,
	EXECUTING,
	OBSERVING,
	VERIFYING,
	WAITING_FOR_APPROVAL,
	WAITING_FOR_CLARIFICATION,
	WAITING_FOR_PLAN_APPROVAL,
	RUNNING_GAME,
	OBSERVING_RUNTIME,
	DEBUGGING,
	COMPLETED,
	ERROR,
	RECOVERING,
	CANCELLED
}

signal state_changed(new_state: AgentState, state_description: String)
signal thinking_received(thinking_text: String)
signal chunk_received(text_delta: String, thinking_delta: String)
signal text_received(role: String, message_text: String)
signal tool_executing(tool_name: String, args: Dictionary)
signal tool_completed(tool_name: String, result: Dictionary)
signal approval_requested(tool_name: String, args: Dictionary, change_set: AISidebarChangeSet)
signal clarification_requested(question: String, options: Array, clarification_id: String)
## Kullanıcıya uygulama planı sunuldu (execution henüz BAŞLAMADI).
signal plan_proposed(plan: AISidebarImplementationPlan)
## Kullanıcı planı onayladı; execution başlıyor.
signal plan_approved(plan: AISidebarImplementationPlan)
## Kullanıcı planı reddetti; hiçbir mutation yapılmadı.
signal plan_rejected(plan: AISidebarImplementationPlan)
signal changes_applied(change_set: AISidebarChangeSet)
signal verification_started(tool_name: String)
signal verification_completed(tool_name: String, is_valid: bool, msg: String)
signal runtime_observation_received(obs: AISidebarRuntimeObservation)
signal debugging_started(error_summary: String)
signal error_occurred(error_message: String)
signal loop_finished()
signal task_completed(metrics: Dictionary)
signal step_progress(current_step: int, max_steps: int)

var provider: AISidebarAIProvider
var context: AISidebarAgentContext
var current_state: AgentState = AgentState.IDLE
var current_step: int = 0
var max_steps: int = 20
var max_recovery_attempts: int = 3
var _recovery_attempt_count: int = 0
var max_empty_response_retries: int = 1
var _empty_response_retry_count: int = 0
var _unlocked_tools: Array = []
var _pending_vision_inputs: Array = []
var last_tools_sent_count: int = 0
var _last_error_signature: String = ""
var _last_tool_signature: String = ""
var _stagnation_count: int = 0

# Detaylı Telemetri & Zaman Sayaçları (Milisaniye)
var task_start_time_msec: int = 0
var _llm_step_start_time: int = 0
var _waiting_start_time: int = 0

var llm_turns_count: int = 0
var tool_calls_count: int = 0
var file_ops_count: int = 0
var editor_ops_count: int = 0
var runtime_ops_count: int = 0
var verification_checkpoints_count: int = 0
## Performance Telemetry: read/search/write ayrımı, fail/retry/limit, dosya kümeleri.
var read_ops_count: int = 0
var search_ops_count: int = 0
var write_ops_count: int = 0
var failed_tool_count: int = 0
var retry_count: int = 0
var limit_hit: bool = false
var files_read: Dictionary = {}
var files_written: Dictionary = {}
var tool_time_by_name: Dictionary = {}

var llm_time_msec: int = 0
var tool_time_msec: int = 0
var file_time_msec: int = 0
var editor_time_msec: int = 0
var runtime_time_msec: int = 0
var verification_time_msec: int = 0
var waiting_time_msec: int = 0
## Research overhead paydası: read + search araçlarında harcanan süre.
var research_time_msec: int = 0

# Bekleyen Onay & Clarification Verisi
var _pending_tool_name: String = ""
var _pending_tool_id: String = ""
var _pending_tool_args: Dictionary = {}
var _pending_change_set: AISidebarChangeSet = null
var _pending_clarification_id: String = ""
var _pending_clarification_question: String = ""
var _pending_clarification_options: Array = []

## Uygulama Planlama Katmanı.
## false yapilirsa planlama kapisi tamamen devre disi kalir ve eski hizli
## execution davranisi birebir korunur (mevcut yurutme testleri bunu kullanir).
var enable_planning_gate: bool = true
var _plan_phase_active: bool = false
var _pending_plan: AISidebarImplementationPlan = null
var runtime_debugger: AISidebarRuntimeDebugger = null

static func get_ts() -> String:
	var dt = Time.get_time_dict_from_system()
	var ms = Time.get_ticks_msec() % 1000
	return "%02d:%02d:%02d.%03d" % [dt.hour, dt.minute, dt.second, ms]

func _init(p_provider: AISidebarAIProvider = null, p_context: AISidebarAgentContext = null) -> void:
	provider = p_provider
	context = p_context
	runtime_debugger = AISidebarRuntimeDebugger.new()
	
	if provider:
		provider.response_received.connect(_on_provider_response)
		provider.chunk_received.connect(_on_provider_chunk)
		provider.error_occurred.connect(_on_provider_error)

func set_provider(p_provider: AISidebarAIProvider) -> void:
	if provider:
		if provider.response_received.is_connected(_on_provider_response):
			provider.response_received.disconnect(_on_provider_response)
		if provider.chunk_received.is_connected(_on_provider_chunk):
			provider.chunk_received.disconnect(_on_provider_chunk)
		if provider.error_occurred.is_connected(_on_provider_error):
			provider.error_occurred.disconnect(_on_provider_error)
	provider = p_provider
	if provider:
		provider.response_received.connect(_on_provider_response)
		provider.chunk_received.connect(_on_provider_chunk)
		provider.error_occurred.connect(_on_provider_error)

func _on_provider_chunk(text_delta: String, thinking_delta: String) -> void:
	if not is_running():
		return
	chunk_received.emit(text_delta, thinking_delta)

func is_running() -> bool:
	return current_state != AgentState.IDLE and current_state != AgentState.COMPLETED and current_state != AgentState.ERROR and current_state != AgentState.CANCELLED

func _set_state(new_state: AgentState, desc: String = "") -> void:
	current_state = new_state
	state_changed.emit(new_state, desc)

func start_task(user_prompt: String, display_prompt: String = "", initial_vision_inputs: Array = []) -> void:
	if is_running() or not context or not provider:
		return
		
	var cfg = AISidebarConfig.load_config()
	max_steps = int(cfg.get("max_agent_steps", cfg.get("max_iterations", 20)))
	current_step = 0
	_recovery_attempt_count = 0
	_empty_response_retry_count = 0
	_unlocked_tools.clear()
	last_tools_sent_count = 0
	_last_error_signature = ""
	_last_tool_signature = ""
	_stagnation_count = 0
	_pending_tool_name = ""
	_pending_tool_id = ""
	_pending_tool_args = {}
	_pending_change_set = null
	_pending_clarification_id = ""
	_pending_clarification_question = ""
	_pending_clarification_options.clear()
	_pending_plan = null
	_pending_vision_inputs.clear()
	if initial_vision_inputs.size() > 0:
		_pending_vision_inputs.append_array(initial_vision_inputs)
	
	# Telemetri Sıfırlama
	task_start_time_msec = Time.get_ticks_msec()
	llm_turns_count = 0
	tool_calls_count = 0
	file_ops_count = 0
	editor_ops_count = 0
	runtime_ops_count = 0
	verification_checkpoints_count = 0
	read_ops_count = 0
	search_ops_count = 0
	write_ops_count = 0
	failed_tool_count = 0
	retry_count = 0
	limit_hit = false
	files_read.clear()
	files_written.clear()
	tool_time_by_name.clear()

	llm_time_msec = 0
	tool_time_msec = 0
	file_time_msec = 0
	editor_time_msec = 0
	runtime_time_msec = 0
	verification_time_msec = 0
	waiting_time_msec = 0
	research_time_msec = 0
	
	var shown_prompt = display_prompt if not display_prompt.is_empty() else user_prompt
	print("[TIMING] %s | TASK_START | prompt=%s" % [get_ts(), shown_prompt.left(60)])
	context.add_user_message(user_prompt, false, display_prompt, initial_vision_inputs)
	text_received.emit("user", shown_prompt)

	# Uygulama Planlama Kapisi: yalnizca orta/buyuk kapsamli isteklerde acilir.
	# Kucuk/tekil isteklerde (or. "speed degerini 300 yap") eski hizli davranis korunur.
	_plan_phase_active = enable_planning_gate and AISidebarPlanningPolicy.should_plan(user_prompt)
	if _plan_phase_active:
		print("[TIMING] %s | PLAN_PHASE_START | plan onayi gerekli" % get_ts())
		context.add_user_message(AISidebarPlanningPolicy.build_plan_directive(user_prompt))

	_set_state(AgentState.PLANNING, AISidebarI18n.get_text("status_thinking"))
	_run_next_step()

func get_elapsed_s() -> float:
	if task_start_time_msec <= 0:
		return 0.0
	return snappedf((Time.get_ticks_msec() - task_start_time_msec) / 1000.0, 0.1)

## Pause sonrası continuation: AYNI task_id ile kaldığı step'ten devam.
## start_task'tan farklı: sayaçlar/step sıfırlanmaz, unlock'lar korunur.
## Dönüş: resume başladıysa true (bulunamazsa false -> dock normal task açar).
func resume_task(cp: Dictionary, resume_text: String, display_text: String = "devam et") -> bool:
	if is_running() or context == null or provider == null:
		return false
	if cp.is_empty() or not bool(cp.get("resumable", false)):
		return false
	var task_id = str(cp.get("task_id", ""))
	if not context.get_transcript().reopen_task(task_id):
		return false
	current_step = maxi(0, int(cp.get("current_step", 0)))
	var cp_max = int(cp.get("max_steps", 0))
	if cp_max > 0:
		max_steps = cp_max
	var kept_elapsed = float(cp.get("elapsed_s", 0.0))
	task_start_time_msec = Time.get_ticks_msec() - int(kept_elapsed * 1000.0) if kept_elapsed > 0.0 else Time.get_ticks_msec()
	_last_tool_signature = ""
	_stagnation_count = 0
	_empty_response_retry_count = 0
	_plan_phase_active = false
	_pending_vision_inputs.clear()
	print("[TIMING] %s | TASK_RESUMED | id=%s step=%d/%d" % [get_ts(), task_id, current_step, max_steps])
	context.add_user_message(resume_text, false, display_text, [])
	text_received.emit("user", display_text)
	_set_state(AgentState.PLANNING, AISidebarI18n.get_text("status_thinking"))
	_run_next_step()
	return true

func stop() -> void:
	if not is_running():
		return
	if provider:
		provider.cancel()
	if runtime_debugger:
		runtime_debugger.stop()
		
	_pending_clarification_id = ""
	_pending_clarification_question = ""
	_pending_clarification_options.clear()
	_pending_plan = null
	_plan_phase_active = false
	_pending_tool_name = ""
	_pending_tool_id = ""
	_pending_tool_args = {}
	_pending_change_set = null
		
	_set_state(AgentState.CANCELLED, AISidebarI18n.get_text("agent_stopped"))
	error_occurred.emit(AISidebarI18n.get_text("agent_stopped"))
	_finish_task(false)

func _finish_task(success: bool) -> void:
	var total_elapsed_sec = (Time.get_ticks_msec() - task_start_time_msec) / 1000.0
	var total_schemas_count = AISidebarToolManager.get_all_schemas().size()
	var metrics = {
		"success": success,
		"elapsed_seconds": snappedf(total_elapsed_sec, 0.1),
		"used_steps": current_step,
		"max_steps": max_steps,
		"steps_summary": str(current_step) + " / " + str(max_steps),
		"tools_sent": last_tools_sent_count,
		"total_tools": total_schemas_count,
		"tools_ratio": str(last_tools_sent_count) + " / " + str(total_schemas_count),
		"llm_turns": llm_turns_count,
		"tool_calls": tool_calls_count,
		"file_ops": file_ops_count,
		"editor_ops": editor_ops_count,
		"runtime_ops": runtime_ops_count,
		"verification_checkpoints": verification_checkpoints_count,
		# Performance Telemetry: read/search/write ayrımı, fail/retry/limit, dosyalar.
		"read_ops": read_ops_count,
		"search_ops": search_ops_count,
		"write_ops": write_ops_count,
		"failed_tools": failed_tool_count,
		"retry_count": retry_count,
		"limit_hit": limit_hit,
		"files_read_count": files_read.size(),
		"files_written_count": files_written.size(),
		"files_read": files_read.keys(),
		"files_written": files_written.keys(),
		"tool_time_by_tool_s": _tool_time_by_tool_seconds(),
		# Detaylı Süre Dağılımı (Saniye)
		"llm_time_s": snappedf(llm_time_msec / 1000.0, 0.1),
		"tool_time_s": snappedf(tool_time_msec / 1000.0, 0.1),
		"file_time_s": snappedf(file_time_msec / 1000.0, 0.1),
		"editor_time_s": snappedf(editor_time_msec / 1000.0, 0.1),
		"runtime_time_s": snappedf(runtime_time_msec / 1000.0, 0.1),
		"verification_time_s": snappedf(verification_time_msec / 1000.0, 0.1),
		"waiting_time_s": snappedf(waiting_time_msec / 1000.0, 0.1),
		"research_time_s": snappedf(research_time_msec / 1000.0, 0.1),
		"research_overhead_ratio": _research_overhead_ratio(total_elapsed_sec)
	}
	print("[TIMING] %s | TASK_COMPLETE | success=%s elapsed=%.3fs llm=%.3fs tool=%.3fs research=%.3fs overhead=%.2f" % [get_ts(), str(success), total_elapsed_sec, llm_time_msec / 1000.0, tool_time_msec / 1000.0, research_time_msec / 1000.0, _research_overhead_ratio(total_elapsed_sec)])
	task_completed.emit(metrics)
	loop_finished.emit()
	_pending_vision_inputs.clear()
	_pending_clarification_id = ""
	_pending_clarification_question = ""
	_pending_clarification_options.clear()
	_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))

## Test edilebilir metrik yardımcıları (pure hesap, sinyal yok).
func _tool_time_by_tool_seconds() -> Dictionary:
	var out: Dictionary = {}
	for k in tool_time_by_name.keys():
		out[k] = snappedf(int(tool_time_by_name[k]) / 1000.0, 0.1)
	return out

## Research overhead = keşif (read+search) süresi / toplam task süresi.
func _research_overhead_ratio(total_elapsed_sec: float) -> float:
	if total_elapsed_sec <= 0.0:
		return 0.0
	return snappedf((research_time_msec / 1000.0) / total_elapsed_sec, 0.01)

## Kullanıcı bekleyen işlemi onayladı (Approve)
func approve_pending_action() -> void:
	if current_state != AgentState.WAITING_FOR_APPROVAL or _pending_tool_name.is_empty():
		return
		
	if _waiting_start_time > 0:
		waiting_time_msec += (Time.get_ticks_msec() - _waiting_start_time)
		_waiting_start_time = 0
		
	var fn_name = _pending_tool_name
	var tc_id = _pending_tool_id
	var args = _pending_tool_args
	var cs = _pending_change_set
	
	_pending_tool_name = ""
	_pending_tool_id = ""
	_pending_tool_args = {}
	_pending_change_set = null
	
	_set_state(AgentState.EXECUTING, "Onaylanan işlem çalıştırılıyor: " + fn_name)
	print("[TIMING] %s | TOOL_START (APPROVED) | tool=%s" % [get_ts(), fn_name])
	tool_executing.emit(fn_name, args)
	
	var t_start = Time.get_ticks_msec()
	var result: Dictionary = await AISidebarToolManager.execute_tool_async(fn_name, args, true)
	var t_delta = Time.get_ticks_msec() - t_start
	tool_time_msec += t_delta
	_record_category_time(fn_name, t_delta)
	_record_tool_telemetry(fn_name, args, t_delta, result)
	
	print("[TIMING] %s | TOOL_DONE (APPROVED) | tool=%s duration=%dms" % [get_ts(), fn_name, t_delta])
	if not fn_name in _unlocked_tools:
		_unlocked_tools.append(fn_name)
	tool_completed.emit(fn_name, result)
	if cs and result.get("success", false):
		changes_applied.emit(cs)

	var verified = _verify_tool_result(fn_name, args, result)
	_complete_tool_turn(fn_name, tc_id, args, result, bool(verified.get("is_valid", false)), str(verified.get("message", "")))
	_run_next_step()

## Kullanıcı bekleyen işlemi reddetti (Reject)
func reject_pending_action(reason: String = "Kullanıcı bu işlemi reddetti.") -> void:
	if current_state != AgentState.WAITING_FOR_APPROVAL or _pending_tool_name.is_empty():
		return
		
	if _waiting_start_time > 0:
		waiting_time_msec += (Time.get_ticks_msec() - _waiting_start_time)
		_waiting_start_time = 0
		
	var fn_name = _pending_tool_name
	var tc_id = _pending_tool_id
	_pending_tool_name = ""
	_pending_tool_id = ""
	_pending_tool_args = {}
	_pending_change_set = null
	
	_set_state(AgentState.RECOVERING, "İşlem reddedildi, ajana bildiriliyor...")
	print("[TIMING] %s | TOOL_REJECTED | tool=%s" % [get_ts(), fn_name])
	var reject_result = AISidebarToolResult.err("USER_REJECTED", reason, true)
	if context:
		context.add_tool_result_message(tc_id, fn_name, reject_result)
	
	_run_next_step()

## Kullanıcı clarification sorusuna yanıt verdiğinde aynı görevi devam ettirir
func submit_clarification_response(answer: String) -> void:
	if current_state != AgentState.WAITING_FOR_CLARIFICATION or _pending_clarification_id.is_empty():
		return
		
	if _waiting_start_time > 0:
		waiting_time_msec += (Time.get_ticks_msec() - _waiting_start_time)
		_waiting_start_time = 0
		
	var tc_id = _pending_clarification_id
	var question = _pending_clarification_question
	_pending_clarification_id = ""
	_pending_clarification_question = ""
	_pending_clarification_options.clear()
	
	print("[TIMING] %s | CLARIFICATION_ANSWERED | answer=%s" % [get_ts(), answer])
	
	var result_dict = {
		"success": true,
		"data": {
			"question": question,
			"user_answer": answer
		},
		"message": "Kullanıcı yanıtı: " + answer
	}
	if context:
		context.add_tool_result_message(tc_id, "ask_user", result_dict)
		
	_set_state(AgentState.EXECUTING, "Kullanıcı yanıtı alındı, göreve devam ediliyor...")
	_run_next_step()

## Kullanıcı sunulan implementation planını onayladı.
## Bu andan itibaren plan fazı KAPANIR; mevcut execution loop'u (tam araç seti ile) devralır.
func approve_plan() -> void:
	if current_state != AgentState.WAITING_FOR_PLAN_APPROVAL:
		return

	if _waiting_start_time > 0:
		waiting_time_msec += (Time.get_ticks_msec() - _waiting_start_time)
		_waiting_start_time = 0

	var plan = _pending_plan
	_pending_plan = null
	_plan_phase_active = false

	print("[TIMING] %s | PLAN_APPROVED" % get_ts())
	plan_approved.emit(plan)
	_set_state(AgentState.EXECUTING, "Plan onaylandı, uygulanıyor...")
	_run_next_step()

## Kullanıcı planı reddetti.
## Bu noktaya kadar HICBIR mutation yapılmadı; görev sonlandırılır.
func reject_plan(reason: String = "Kullanıcı planı reddetti.") -> void:
	if current_state != AgentState.WAITING_FOR_PLAN_APPROVAL:
		return

	if _waiting_start_time > 0:
		waiting_time_msec += (Time.get_ticks_msec() - _waiting_start_time)
		_waiting_start_time = 0

	var plan = _pending_plan
	_pending_plan = null
	_plan_phase_active = false

	print("[TIMING] %s | PLAN_REJECTED | reason=%s" % [get_ts(), reason])
	plan_rejected.emit(plan)
	_set_state(AgentState.CANCELLED, reason)
	_finish_task(false)

## Çalışma zamanı hatası alındığında otomatik iyileştirme döngüsünü tetikler
func handle_runtime_error(obs: AISidebarRuntimeObservation) -> void:
	if not is_running():
		return
		
	runtime_observation_received.emit(obs)
	
	var err_sig = ""
	if obs.errors.size() > 0:
		var e0 = obs.errors[0]
		err_sig = e0.get("file", "") + ":" + str(e0.get("line", 0)) + ":" + e0.get("message", "")
		
	if err_sig == _last_error_signature and not err_sig.is_empty():
		_recovery_attempt_count += 1
		if _recovery_attempt_count > max_recovery_attempts:
			_set_state(AgentState.ERROR, "Aynı çalışma zamanı hatası çözülemedi.")
			error_occurred.emit("Otomatik iyileştirme limiti aşıldı: " + err_sig)
			_finish_task(false)
			return
	else:
		_last_error_signature = err_sig
		_recovery_attempt_count = 1
		
	_set_state(AgentState.DEBUGGING, "Çalışma zamanı hatası analiz ediliyor...")
	var summary_txt = obs.errors[0].get("message", "Runtime Error") if obs.errors.size() > 0 else "Runtime Error"
	debugging_started.emit(summary_txt)
	
	if context:
		context.add_runtime_error_context(obs)
		
	_run_next_step()

func _run_next_step() -> void:
	if not is_running() or not context or not provider:
		return
		
	current_step += 1
	if context:
		context.get_transcript().mark_step(current_step)
	if current_step > max_steps:
		limit_hit = true
		_set_state(AgentState.ERROR, "Maksimum ajan adım limitine (" + str(max_steps) + ") ulaşıldı.")
		error_occurred.emit("Maksimum ajan adım limitine (" + str(max_steps) + ") ulaşıldı.")
		_finish_task(false)
		return
		
	step_progress.emit(current_step, max_steps)
	llm_turns_count += 1
	var status_msg = "Agent Step " + str(current_step) + " / " + str(max_steps)
	_set_state(AgentState.PLANNING, status_msg)
	
	_llm_step_start_time = Time.get_ticks_msec()
	var context_text = ""
	if context:
		for msg in context.messages:
			var role = msg.get("role", "")
			if role == "user":
				var c = msg.get("content", "")
				if c is String:
					context_text += " " + c
				
	# Planlama fazinda modele yalnizca mutation URETMEYEN araclar sunulur.
	var tools_schema = AISidebarToolManager.get_relevant_schemas(context_text, _unlocked_tools, _plan_phase_active)
	last_tools_sent_count = tools_schema.size()
	
	if current_step > 1:
		print("[TIMING] %s | NEXT_LLM_REQUEST_START | step=%d/%d tools=%d/%d" % [get_ts(), current_step, max_steps, last_tools_sent_count, AISidebarToolManager.get_all_schemas().size()])
	else:
		print("[TIMING] %s | LLM_REQUEST_START | step=1/%d tools=%d/%d" % [get_ts(), max_steps, last_tools_sent_count, AISidebarToolManager.get_all_schemas().size()])
		
	var messages = context.get_messages_for_api()
	_dispatch_llm_turn(messages, tools_schema)

## LLM turu gönderimi: vision varsa ve provider destekliyorsa multimodal,
## desteklemiyorsa görüntüler "saved but not sent" kaydıyla düşürülür
## (sessiz birikme yok; modelin gördüğü izlenimi yok).
func _dispatch_llm_turn(messages: Array, tools_schema: Array) -> void:
	if provider == null:
		return
	if _pending_vision_inputs.size() > 0:
		if provider.has_method("supports_vision") and provider.supports_vision() and provider.has_method("send_multimodal_chat"):
			var imgs = _pending_vision_inputs.duplicate()
			_pending_vision_inputs.clear()
			provider.send_multimodal_chat(messages, tools_schema, imgs)
			return
		var dropped_paths: Array = []
		for vi in _pending_vision_inputs:
			if vi is AISidebarVisionInput:
				dropped_paths.append((vi as AISidebarVisionInput).image_path)
		_pending_vision_inputs.clear()
		if context != null:
			context.get_transcript().record("vision_dropped", {"reason": "provider_no_vision", "paths": dropped_paths})
	provider.send_chat(messages, tools_schema)

func _on_provider_response(text_content: String, thinking_content: String, tool_calls: Array) -> void:
	if not is_running():
		return
		
	if _llm_step_start_time > 0:
		var delta_req = Time.get_ticks_msec() - _llm_step_start_time
		llm_time_msec += delta_req
		_llm_step_start_time = 0
		
	# Boş Yanıt Kontrolü (Empty Response Guard & Controlled Retry)
	if text_content.is_empty() and thinking_content.is_empty() and tool_calls.is_empty():
		if _empty_response_retry_count < max_empty_response_retries:
			_empty_response_retry_count += 1
			_note_retry()
			print("[TIMING] %s | PROVIDER_EMPTY_RESPONSE_RETRY | attempt=%d/%d" % [get_ts(), _empty_response_retry_count, max_empty_response_retries])
			_set_state(AgentState.RECOVERING, "Geçici boş yanıt alındı, tekrar deneniyor...")
			_run_next_step()
			return
		else:
			_set_state(AgentState.ERROR, "Modelden boş yanıt alındı.")
			error_occurred.emit("Model boş yanıt döndürdü (PROVIDER_EMPTY_RESPONSE).")
			_finish_task(false)
			return
			
	_empty_response_retry_count = 0
		
	# 1. Thinking
	if not thinking_content.is_empty():
		thinking_received.emit(thinking_content)
		
	# 2. Metin Yanıtı
	if not text_content.is_empty():
		text_received.emit("assistant", text_content)
		
	# 3. Araç İcrası
	if tool_calls.size() > 0:
		if context:
			context.add_assistant_tool_call_message(text_content, tool_calls, thinking_content)
			
		for _tc_idx in range(tool_calls.size()):
			var tc = tool_calls[_tc_idx]
			var fn_name: String = tc.get("name", "")
			var tc_id: String = tc.get("id", "call_default")
			var args: Dictionary = tc.get("arguments", {})
			
			tool_calls_count += 1
			if not fn_name in _unlocked_tools:
				_unlocked_tools.append(fn_name)
			
			# Stagnation Guard
			var sig = fn_name + ":" + JSON.stringify(args)
			if sig == _last_tool_signature:
				_stagnation_count += 1
				if _stagnation_count >= 2:
					_set_state(AgentState.ERROR, "Aynı araç (" + fn_name + ") tekrar tekrar çağrıldı.")
					error_occurred.emit("Ajan aynı aracı (" + fn_name + ") tekrarladı. Görev sonlandırıldı.")
					_finish_task(false)
					return
				else:
					if context:
						context.add_user_message("SİSTEM BİLGİSİ: '" + fn_name + "' aracı zaten çalıştırıldı. Sonuç yukarıda mevcuttur. Lütfen aynı aracı tekrar çağırmadan yanıt verin.")
					_defer_remaining_calls(tool_calls.slice(_tc_idx + 1), "DEFERRED_AFTER_STAGNATION_WARNING", "Tekrarlanan çağrı nedeniyle yeni tura geçildi; bu çağrı ertelendi.")
					_run_next_step()
					return
			else:
				_last_tool_signature = sig
				_stagnation_count = 0
				
			# Kullanıcıdan Netleştirme İsteme (Clarification Intercept)
			if fn_name == "ask_user":
				var question = str(args.get("question", "Lütfen seçiminizi belirtin."))
				var options_raw = args.get("options", [])
				var options: Array = []
				if options_raw is Array:
					for opt in options_raw:
						options.append(str(opt))
						
				_pending_clarification_id = tc_id
				_pending_clarification_question = question
				_pending_clarification_options = options
				_waiting_start_time = Time.get_ticks_msec()
				
				_set_state(AgentState.WAITING_FOR_CLARIFICATION, "Kullanıcıdan yanıt bekleniyor...")
				print("[TIMING] %s | CLARIFICATION_REQUESTED | question=%s options=%s" % [get_ts(), question, str(options)])
				_defer_remaining_calls(tool_calls.slice(_tc_idx + 1), "DEFERRED_FOR_CLARIFICATION", "Kullanıcı yanıtı bekleniyor; bu çağrı ertelendi. Gerekirse yanıt sonrası tekrar isteyin.")
				clarification_requested.emit(question, options, tc_id)
				return

			# Uygulama Planı Sunumu (Plan Review Intercept)
			# ask_user gibi: araç ÇALIŞTIRILMAZ, plan kullanıcıya sunulur ve onay beklenir.
			if fn_name == "propose_plan":
				var plan = AISidebarImplementationPlan.new(args)
				_pending_plan = plan
				_waiting_start_time = Time.get_ticks_msec()

				_set_state(AgentState.WAITING_FOR_PLAN_APPROVAL, "Plan onayı bekleniyor...")
				print("[TIMING] %s | PLAN_PROPOSED | steps=%d files=%d" % [get_ts(), plan.steps.size(), plan.affected_files.size()])
				_defer_remaining_calls(tool_calls.slice(_tc_idx + 1), "DEFERRED_FOR_PLAN", "Plan onayı bekleniyor; bu çağrı ertelendi. Gerekirse onay sonrası tekrar isteyin.")
				plan_proposed.emit(plan)
				return

			# Mutation Guard: plan fazı aktifken değiştirici araç çağrılamaz.
			# Bu kontrol LLM davranışına bırakılmaz; DETERMINISTIK olarak uygulanır.
			# Stagnation kontrolünden SONRA çalışır ki tekrarlanan engellenmiş çağrılar
			# modeli uyaran mevcut mekanizmayı atlamasın.
			if _plan_phase_active and AISidebarPlanningPolicy.is_mutation_blocked(fn_name):
				print("[TIMING] %s | PLAN_PHASE_MUTATION_BLOCKED | tool=%s" % [get_ts(), fn_name])
				var blocked = AISidebarToolResult.err(
					"PLAN_PHASE_MUTATION_BLOCKED",
					"Plan onaylanmadan '" + fn_name + "' çalıştırılamaz. Lütfen önce 'propose_plan' ile plan sunun.",
					true
				)
				if context:
					context.add_tool_result_message(tc_id, fn_name, blocked)
				# Engellenen çağrı kuyruğu durdurmaz; sonraki (izinli) çağrılar
				# aynı turda işlenmeye devam eder, tur sonu tek _run_next_step.
				continue

			# Telemetri sınıflandırması guard'dan SONRA yapılır; böylece engellenen
			# (hiç çalışmayan) bir işlem 'file_ops' / 'editor_ops' olarak SAYILMAZ.
			_classify_telemetry_op(fn_name, args)

			# Değişiklik Öncesi Eski İçerikleri Kaydet (ChangeSet Hazırlığı)
			var cs = _build_changeset_for_tool(fn_name, args)
			
			# Yetki ve Onay Kontrolü
			_set_state(AgentState.EXECUTING, "Araç çalıştırılıyor: " + fn_name)
			print("[TIMING] %s | TOOL_START | tool=%s" % [get_ts(), fn_name])
			tool_executing.emit(fn_name, args)
			
			var t_start = Time.get_ticks_msec()
			var result: Dictionary = await AISidebarToolManager.execute_tool_async(fn_name, args, false)
			if not is_running():
				return
			var t_delta = Time.get_ticks_msec() - t_start
			tool_time_msec += t_delta
			_record_category_time(fn_name, t_delta)
			_record_tool_telemetry(fn_name, args, t_delta, result)
			
			# search_tools ile keşfedilen araçları dynamic context'e ekle
			if fn_name == "search_tools" and result.get("success", false):
				var s_data = result.get("data", {})
				var s_list = s_data.get("tools", [])
				for s_item in s_list:
					var s_name = s_item.get("name", "")
					if not s_name.is_empty() and not s_name in _unlocked_tools:
						_unlocked_tools.append(s_name)
			
			print("[TIMING] %s | TOOL_DONE | tool=%s duration=%dms" % [get_ts(), fn_name, t_delta])
			
			# Onay gerekiyorsa durakla
			if not result.get("success", false) and result.get("error", {}).get("code", "") == "APPROVAL_REQUIRED":
				_pending_tool_name = fn_name
				_pending_tool_id = tc_id
				_pending_tool_args = args
				_pending_change_set = cs
				_waiting_start_time = Time.get_ticks_msec()
				_set_state(AgentState.WAITING_FOR_APPROVAL, "Kullanıcı onayı bekleniyor (" + fn_name + ")")
				print("[TIMING] %s | APPROVAL_REQUESTED | tool=%s" % [get_ts(), fn_name])
				_defer_remaining_calls(tool_calls.slice(_tc_idx + 1), "DEFERRED_FOR_APPROVAL", "Kullanıcı onayı bekleniyor; bu çağrı ertelendi. Gerekirse onay sonrası tekrar isteyin.")
				approval_requested.emit(fn_name, args, cs)
				return
				
			tool_completed.emit(fn_name, result)
			if cs and result.get("success", false):
				changes_applied.emit(cs)
				
			if fn_name == "play_game" or fn_name == "restart_game":
				_set_state(AgentState.RUNNING_GAME, "Oyun çalışıyor...")
				
			var verified = _verify_tool_result(fn_name, args, result)
			_complete_tool_turn(fn_name, tc_id, args, result, bool(verified.get("is_valid", false)), str(verified.get("message", "")))
		# Tüm kuyruk aynı turda işlendi; tek LLM turu harcandı.
		_run_next_step()
	else:
		if not text_content.is_empty() and context:
			context.add_assistant_message(text_content)
			
		_set_state(AgentState.COMPLETED, AISidebarI18n.get_text("status_ready"))
		_finish_task(true)

func _build_changeset_for_tool(fn_name: String, args: Dictionary) -> AISidebarChangeSet:
	if fn_name == "create_or_update_script":
		var path = args.get("file_path", "")
		var old_c = ""
		var c_type = AISidebarChangeSet.ChangeType.CREATE_FILE
		if FileAccess.file_exists(path):
			c_type = AISidebarChangeSet.ChangeType.MODIFY_FILE
			var f = FileAccess.open(path, FileAccess.READ)
			if f: old_c = f.get_as_text(); f.close()
		return AISidebarChangeSet.new(path, c_type, args.get("content", ""), old_c, "Script güncellemesi")
	elif fn_name == "replace_file_content":
		var path = args.get("file_path", "")
		var target_code = args.get("target_code", "")
		var replacement_code = args.get("replacement_code", "")
		var old_c = ""
		var new_c = ""
		if FileAccess.file_exists(path):
			var f = FileAccess.open(path, FileAccess.READ)
			if f:
				old_c = f.get_as_text()
				f.close()
				var idx = old_c.find(target_code)
				if idx != -1:
					new_c = old_c.substr(0, idx) + replacement_code + old_content_after(old_c, idx, target_code.length())
				else:
					new_c = old_c
		return AISidebarChangeSet.new(path, AISidebarChangeSet.ChangeType.MODIFY_FILE, new_c, old_c, "Cerrahi kod güncellemesi")
	elif fn_name == "write_files":
		var cs = AISidebarChangeSet.new("", AISidebarChangeSet.ChangeType.MODIFY_FILE, "", "", "Toplu dosya yazımı")
		var f_arr = args.get("files", [])
		for f_item in f_arr:
			if f_item is Dictionary:
				var f_p = f_item.get("file_path", "")
				var f_c = f_item.get("content", "")
				var old_txt = ""
				var c_type = AISidebarChangeSet.ChangeType.CREATE_FILE
				if FileAccess.file_exists(f_p):
					c_type = AISidebarChangeSet.ChangeType.MODIFY_FILE
					var f_rd = FileAccess.open(f_p, FileAccess.READ)
					if f_rd: old_txt = f_rd.get_as_text(); f_rd.close()
				cs.add_sub_change(f_p, c_type, f_c, old_txt, f_p.get_file())
		return cs
	elif fn_name == "delete_node":
		return AISidebarChangeSet.new(args.get("node_path", ""), AISidebarChangeSet.ChangeType.MUTATE_SCENE, "", "", "Düğüm silme: " + args.get("node_path", ""))
	return null

func old_content_after(s: String, idx: int, len_target: int) -> String:
	return s.substr(idx + len_target)

func _classify_telemetry_op(fn_name: String, args: Dictionary) -> void:
	match fn_name:
		"create_or_update_script", "replace_file_content", "delete_file", "create_scene", "save_scene":
			file_ops_count += 1
		"write_files":
			var files_arr = args.get("files", [])
			file_ops_count += maxi(1, files_arr.size())
		"add_node", "delete_node", "rename_node", "duplicate_node", "set_node_property", "connect_signal", "reparent_node", "select_node":
			editor_ops_count += 1
		"play_game", "stop_game", "restart_game", "get_runtime_errors", "take_runtime_screenshot":
			runtime_ops_count += 1

func _record_category_time(fn_name: String, duration_msec: int) -> void:
	match fn_name:
		"create_or_update_script", "create_scene", "save_scene", "write_files":
			file_time_msec += duration_msec
		"add_node", "delete_node", "rename_node", "duplicate_node", "set_node_property", "connect_signal", "reparent_node", "select_node":
			editor_time_msec += duration_msec
		"play_game", "stop_game", "restart_game", "get_runtime_errors", "take_runtime_screenshot":
			runtime_time_msec += duration_msec

## Tool türü sınıflandırması (pure/static; Research Budget da bunu kullanacak).
## "read" | "search" | "write" | "verify" | "runtime" | "editor" | "other"
static func classify_tool_kind(tool_name: String) -> String:
	match tool_name:
		"read_script", "read_file", "get_project_files", "list_files", "analyze_project":
			return "read"
		"search_tools":
			return "search"
		"create_or_update_script", "replace_file_content", "write_files", "create_scene", "save_scene", "delete_file":
			return "write"
		"validate_script":
			return "verify"
		"play_game", "stop_game", "restart_game", "get_runtime_errors", "take_runtime_screenshot":
			return "runtime"
		"add_node", "delete_node", "rename_node", "duplicate_node", "set_node_property", "connect_signal", "reparent_node", "select_node":
			return "editor"
		_:
			if tool_name.begins_with("search"):
				return "search"
			if tool_name.begins_with("read") or tool_name.begins_with("get_"):
				return "read"
			return "other"

func _note_retry() -> void:
	retry_count += 1

## Her GERÇEK tool icrası için tek kayıt noktası (normal + onaylı yol).
## Başarı hükmü transcript helper ile (outer ok + payload fail yakalanır).
func _record_tool_telemetry(fn_name: String, args: Dictionary, duration_msec: int, result: Dictionary) -> void:
	var kind = classify_tool_kind(fn_name)
	match kind:
		"read":
			read_ops_count += 1
			research_time_msec += duration_msec
		"search":
			search_ops_count += 1
			research_time_msec += duration_msec
		"write":
			write_ops_count += 1
	tool_time_by_name[fn_name] = int(tool_time_by_name.get(fn_name, 0)) + duration_msec
	for f in _telemetry_file_targets(args):
		if kind == "write":
			files_written[f] = true
		else:
			files_read[f] = true
	var outcome = AISidebarTaskTranscript.effective_tool_outcome(result)
	if not bool(outcome.get("success", false)):
		failed_tool_count += 1

static func _telemetry_file_targets(args: Dictionary) -> Array:
	var out: Array = []
	if args == null:
		return out
	for k in ["file_path", "scene_path"]:
		var v = str(args.get(k, "")).strip_edges()
		if not v.is_empty():
			out.append(v)
	var files = args.get("files", [])
	if files is Array:
		for f in files:
			if f is Dictionary:
				var fp = str((f as Dictionary).get("file_path", (f as Dictionary).get("path", ""))).strip_edges()
				if not fp.is_empty():
					out.append(fp)
	return out

## Kalan kuyruk çağrılarını erteler: her birine açık DEFERRED sonucu yazılır
## (sessiz kayıp yok) ve tool_completed yayılır; körlemesine icra yapılmaz.
func _defer_remaining_calls(remaining: Array, code: String, message: String) -> void:
	if remaining.is_empty() or context == null:
		return
	for tc in remaining:
		var deferred = AISidebarToolResult.err(code, message + " (Araç: " + str(tc.get("name", "")) + ")", true)
		context.add_tool_result_message(str(tc.get("id", "call_default")), str(tc.get("name", "")), deferred)
		tool_completed.emit(str(tc.get("name", "")), deferred)

## Doğrulama kararı (yan etkisiz hüküm; tur ilerletmez).
func _verify_tool_result(tool_name: String, args: Dictionary, result: Variant) -> Dictionary:
	var res_dict = result if result is Dictionary else {}
	var is_valid = res_dict.get("success", false)
	var ui_msg = str(res_dict.get("message", ""))

	var needs_explicit_verify = (tool_name == "validate_script" or tool_name == "play_game" or tool_name == "get_runtime_errors")

	if needs_explicit_verify:
		_set_state(AgentState.VERIFYING, "Doğrulanıyor: " + tool_name)
		print("[TIMING] %s | VERIFICATION_START | tool=%s" % [get_ts(), tool_name])
		verification_started.emit(tool_name)
		verification_checkpoints_count += 1

		var v_start = Time.get_ticks_msec()
		var verified_result = AISidebarVerificationPipeline.auto_verify_tool_execution(tool_name, args, res_dict)
		var v_delta = Time.get_ticks_msec() - v_start
		verification_time_msec += v_delta

		is_valid = verified_result.get("success", false)
		ui_msg = verified_result.get("message", ui_msg)
		print("[TIMING] %s | VERIFICATION_DONE | tool=%s duration=%dms valid=%s" % [get_ts(), tool_name, v_delta, str(is_valid)])
		verification_completed.emit(tool_name, is_valid, ui_msg)

	return {"is_valid": is_valid, "message": ui_msg}

## Tek tool turunun kapanışı: sonuç context'e, vision kuyruğa (tur ilerletmez).
func _complete_tool_turn(tool_name: String, tool_call_id: String, args: Dictionary, result: Variant, is_valid: bool, ui_msg: String) -> void:
	var res_dict = result if result is Dictionary else {}
	_set_state(AgentState.OBSERVING, "Sonuçlar analiz ediliyor...")
	if context:
		var final_payload: Dictionary = {}
		if res_dict.has("data") and res_dict["data"] != null:
			final_payload = {
				"success": is_valid,
				"data": res_dict["data"],
				"message": ui_msg
			}
		else:
			final_payload = res_dict

		context.add_tool_result_message(tool_call_id, tool_name, final_payload)

	# Görsel Gözlem (Vision Data) Varsa Multimodal Kuyruğuna Ekle
	if is_valid and res_dict.has("data") and res_dict["data"] is Dictionary:
		var v_data = res_dict["data"]
		if v_data.get("has_vision_data", false) == true and not v_data.get("base64", "").is_empty():
			var vi = AISidebarVisionInput.new(
				v_data.get("path", ""),
				v_data.get("base64", ""),
				int(v_data.get("width", 0)),
				int(v_data.get("height", 0))
			)
			_pending_vision_inputs.append(vi)

	print("[TIMING] %s | AGENT_CONTINUE | next_step=%d" % [get_ts(), current_step + 1])

func _on_provider_error(error_message: String) -> void:
	if not is_running():
		return
		
	if ("PROVIDER_EMPTY_RESPONSE" in error_message or "boş yanıt" in error_message) and _empty_response_retry_count < max_empty_response_retries:
		_empty_response_retry_count += 1
		_note_retry()
		print("[TIMING] %s | PROVIDER_EMPTY_ERROR_RETRY | attempt=%d/%d" % [get_ts(), _empty_response_retry_count, max_empty_response_retries])
		_set_state(AgentState.RECOVERING, "Geçici ağ/boş yanıt hatası, tekrar deneniyor...")
		_run_next_step()
		return
		
	_set_state(AgentState.ERROR, error_message)
	print("[TIMING] %s | PROVIDER_ERROR | err=%s" % [get_ts(), error_message])
	error_occurred.emit(error_message)
	_finish_task(false)
