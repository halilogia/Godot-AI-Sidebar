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
const AISidebarCompletionPolicy = preload("res://addons/godot_sidebar_ai/core/agent/completion_policy.gd")
const AISidebarImplementationPlan = preload("res://addons/godot_sidebar_ai/core/types/implementation_plan.gd")
const AISidebarAgentTelemetry = preload("res://addons/godot_sidebar_ai/core/agent/agent_telemetry.gd")
const AISidebarPendingInteraction = preload("res://addons/godot_sidebar_ai/core/agent/pending_interaction.gd")

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

## Sayaçlar, süre dağılımı ve task sonu metrikleri (runner başına ayrı örnek).
var telemetry: AISidebarAgentTelemetry = AISidebarAgentTelemetry.new()
var plan_was_approved: bool = false
## Kurtarılmamış başarısızlıklar (anahtar -> {"tool": String, "deferred": bool}).
## Aynı tool+hedef sonradan başarıyla çalışırsa silinir (recovery kanıtı).
var unrecovered_failures: Dictionary = {}
## Son completion hükmü (metrics'e yazılır; success/incomplete/failed/cancelled).
var last_completion: Dictionary = {"verdict": "success", "reason": "Task completed."}

## Bekleyen kullanıcı kararları: tool onayı, netleştirme sorusu, plan.
var pending: AISidebarPendingInteraction = AISidebarPendingInteraction.new()

## Uygulama Planlama Katmanı.
## false yapilirsa planlama kapisi tamamen devre disi kalir ve eski hizli
## execution davranisi birebir korunur (mevcut yurutme testleri bunu kullanir).
var enable_planning_gate: bool = true
var _plan_phase_active: bool = false
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
	pending.clear_all()
	_pending_vision_inputs.clear()
	if initial_vision_inputs.size() > 0:
		_pending_vision_inputs.append_array(initial_vision_inputs)
	
	# Telemetri Sıfırlama
	telemetry.reset()
	plan_was_approved = false
	unrecovered_failures.clear()
	last_completion = {"verdict": "success", "reason": "Task completed."}
	
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
	return telemetry.get_elapsed_s()

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
	telemetry.task_start_time_msec = Time.get_ticks_msec() - int(kept_elapsed * 1000.0) if kept_elapsed > 0.0 else Time.get_ticks_msec()
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
		
	pending.clear_all()
	_plan_phase_active = false
		
	_set_state(AgentState.CANCELLED, AISidebarI18n.get_text("agent_stopped"))
	error_occurred.emit(AISidebarI18n.get_text("agent_stopped"))
	last_completion = {"verdict": "cancelled", "reason": "Stopped by user."}
	_finish_task(false)

func _finish_task(success: bool) -> void:
	var total_elapsed_sec = (Time.get_ticks_msec() - telemetry.task_start_time_msec) / 1000.0
	var total_schemas_count = AISidebarToolManager.get_all_schemas().size()
	var metrics = telemetry.build_metrics(success, last_completion, current_step, max_steps, last_tools_sent_count, total_schemas_count, total_elapsed_sec)
	print("[TIMING] %s | TASK_COMPLETE | success=%s elapsed=%.3fs llm=%.3fs tool=%.3fs research=%.3fs overhead=%.2f" % [get_ts(), str(success), total_elapsed_sec, telemetry.llm_time_msec / 1000.0, telemetry.tool_time_msec / 1000.0, telemetry.research_time_msec / 1000.0, telemetry.research_overhead_ratio(total_elapsed_sec)])
	task_completed.emit(metrics)
	loop_finished.emit()
	_pending_vision_inputs.clear()
	pending.clear_clarification()
	_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))

## Kullanıcı bekleyen işlemi onayladı (Approve)
func approve_pending_action() -> void:
	if current_state != AgentState.WAITING_FOR_APPROVAL or not pending.has_approval():
		return
		
	telemetry.end_waiting()
		
	var req = pending.take_approval()
	var fn_name = req["name"]
	var tc_id = req["id"]
	var args = req["args"]
	var cs = req["change_set"]
	
	_set_state(AgentState.EXECUTING, "Onaylanan işlem çalıştırılıyor: " + fn_name)
	print("[TIMING] %s | TOOL_START (APPROVED) | tool=%s" % [get_ts(), fn_name])
	tool_executing.emit(fn_name, args)
	
	var t_start = Time.get_ticks_msec()
	var result: Dictionary = await AISidebarToolManager.execute_tool_async(fn_name, args, true)
	var t_delta = Time.get_ticks_msec() - t_start
	telemetry.tool_time_msec += t_delta
	telemetry.record_category_time(fn_name, t_delta)
	telemetry.record_tool(fn_name, args, t_delta, result)
	
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
	if current_state != AgentState.WAITING_FOR_APPROVAL or not pending.has_approval():
		return
		
	telemetry.end_waiting()
		
	var req = pending.take_approval()
	var fn_name = req["name"]
	var tc_id = req["id"]
	
	_set_state(AgentState.RECOVERING, "İşlem reddedildi, ajana bildiriliyor...")
	print("[TIMING] %s | TOOL_REJECTED | tool=%s" % [get_ts(), fn_name])
	var reject_result = AISidebarToolResult.err("USER_REJECTED", reason, true)
	if context:
		context.add_tool_result_message(tc_id, fn_name, reject_result)
	
	_run_next_step()

## Kullanıcı clarification sorusuna yanıt verdiğinde aynı görevi devam ettirir
func submit_clarification_response(answer: String) -> void:
	if current_state != AgentState.WAITING_FOR_CLARIFICATION or not pending.has_clarification():
		return
		
	telemetry.end_waiting()
		
	var req = pending.take_clarification()
	var tc_id = req["id"]
	var question = req["question"]
	
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

	telemetry.end_waiting()

	var req = pending.take_plan()
	var plan = req["plan"]
	var plan_id = req["id"]
	_plan_phase_active = false
	plan_was_approved = true

	# Katı gateway'ler her tool_call için eşleşen tool sonucu ister;
	# onay da propose_plan çağrısının sonucu olarak kaydedilir.
	if context and not plan_id.is_empty():
		context.add_tool_result_message(plan_id, "propose_plan", {
			"success": true,
			"data": {"approved": true},
			"message": "Plan kullanıcı tarafından onaylandı, uygulanıyor."
		})

	print("[TIMING] %s | PLAN_APPROVED" % get_ts())
	plan_approved.emit(plan)
	_set_state(AgentState.EXECUTING, "Plan onaylandı, uygulanıyor...")
	_run_next_step()

## Kullanıcı planı reddetti.
## Bu noktaya kadar HICBIR mutation yapılmadı; görev sonlandırılır.
func reject_plan(reason: String = "Kullanıcı planı reddetti.") -> void:
	if current_state != AgentState.WAITING_FOR_PLAN_APPROVAL:
		return

	telemetry.end_waiting()

	var req = pending.take_plan()
	var plan = req["plan"]
	var plan_id = req["id"]
	_plan_phase_active = false

	if context and not plan_id.is_empty():
		context.add_tool_result_message(plan_id, "propose_plan", AISidebarToolResult.err("PLAN_REJECTED", reason))

	print("[TIMING] %s | PLAN_REJECTED | reason=%s" % [get_ts(), reason])
	plan_rejected.emit(plan)
	_set_state(AgentState.CANCELLED, reason)
	last_completion = {"verdict": "cancelled", "reason": reason}
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
			last_completion = {"verdict": "failed", "reason": "Otomatik iyileştirme limiti aşıldı: " + err_sig}
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
		telemetry.limit_hit = true
		_set_state(AgentState.ERROR, "Maksimum ajan adım limitine (" + str(max_steps) + ") ulaşıldı.")
		error_occurred.emit("Maksimum ajan adım limitine (" + str(max_steps) + ") ulaşıldı.")
		last_completion = {"verdict": "failed", "reason": "Step limit reached (" + str(current_step) + " / " + str(max_steps) + ")."}
		_finish_task(false)
		return
		
	step_progress.emit(current_step, max_steps)
	telemetry.llm_turns_count += 1
	var status_msg = "Agent Step " + str(current_step) + " / " + str(max_steps)
	_set_state(AgentState.PLANNING, status_msg)
	
	telemetry.begin_llm_step()
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
		
	telemetry.end_llm_step()
		
	# Boş Yanıt Kontrolü (Empty Response Guard & Controlled Retry)
	if text_content.is_empty() and thinking_content.is_empty() and tool_calls.is_empty():
		if _empty_response_retry_count < max_empty_response_retries:
			_empty_response_retry_count += 1
			telemetry.note_retry()
			print("[TIMING] %s | PROVIDER_EMPTY_RESPONSE_RETRY | attempt=%d/%d" % [get_ts(), _empty_response_retry_count, max_empty_response_retries])
			_set_state(AgentState.RECOVERING, "Geçici boş yanıt alındı, tekrar deneniyor...")
			_run_next_step()
			return
		else:
			_set_state(AgentState.ERROR, "Modelden boş yanıt alındı.")
			error_occurred.emit("Model boş yanıt döndürdü (PROVIDER_EMPTY_RESPONSE).")
			last_completion = {"verdict": "failed", "reason": "Model boş yanıt döndürdü (PROVIDER_EMPTY_RESPONSE)."}
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
			
			telemetry.tool_calls_count += 1
			if not fn_name in _unlocked_tools:
				_unlocked_tools.append(fn_name)
			
			# Stagnation Guard
			var sig = fn_name + ":" + JSON.stringify(args)
			if sig == _last_tool_signature:
				_stagnation_count += 1
				if _stagnation_count >= 2:
					_set_state(AgentState.ERROR, "Aynı araç (" + fn_name + ") tekrar tekrar çağrıldı.")
					error_occurred.emit("Ajan aynı aracı (" + fn_name + ") tekrarladı. Görev sonlandırıldı.")
					last_completion = {"verdict": "failed", "reason": "Ajan aynı aracı (" + fn_name + ") tekrarladı."}
					_finish_task(false)
					return
				else:
					if context:
						context.add_user_message("SİSTEM BİLGİSİ: '" + fn_name + "' aracı zaten çalıştırıldı. Sonuç yukarıda mevcuttur. Lütfen aynı aracı tekrar çağırmadan yanıt verin.")
						# Katı gateway'ler her tool_call için sonuç ister; tekrar da kayıtsız kalmaz.
						context.add_tool_result_message(tc_id, fn_name, AISidebarToolResult.err("DUPLICATE_CALL", "'" + fn_name + "' zaten çalıştırıldı; yukarıdaki sonuç geçerlidir.", true))
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
						
				pending.request_clarification(tc_id, question, options)
				telemetry.begin_waiting()
				
				_set_state(AgentState.WAITING_FOR_CLARIFICATION, "Kullanıcıdan yanıt bekleniyor...")
				print("[TIMING] %s | CLARIFICATION_REQUESTED | question=%s options=%s" % [get_ts(), question, str(options)])
				_defer_remaining_calls(tool_calls.slice(_tc_idx + 1), "DEFERRED_FOR_CLARIFICATION", "Kullanıcı yanıtı bekleniyor; bu çağrı ertelendi. Gerekirse yanıt sonrası tekrar isteyin.")
				clarification_requested.emit(question, options, tc_id)
				return

			# Uygulama Planı Sunumu (Plan Review Intercept)
			# ask_user gibi: araç ÇALIŞTIRILMAZ, plan kullanıcıya sunulur ve onay beklenir.
			if fn_name == "propose_plan":
				var plan = AISidebarImplementationPlan.new(args)
				pending.propose_plan(plan, tc_id)
				telemetry.begin_waiting()

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
			telemetry.classify_op(fn_name, args)

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
			telemetry.tool_time_msec += t_delta
			telemetry.record_category_time(fn_name, t_delta)
			telemetry.record_tool(fn_name, args, t_delta, result)
			
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
				pending.request_approval(fn_name, tc_id, args, cs)
				telemetry.begin_waiting()
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
		# Completion Integrity Gate: toolsuz final metin tek başına SUCCESS değildir.
		var gate_state = {
			"tool_calls": telemetry.tool_calls_count,
			"unrecovered": unrecovered_failures,
			"plan_approved": plan_was_approved,
			"mutations_done": (telemetry.file_ops_count + telemetry.editor_ops_count + telemetry.write_ops_count) > 0,
			"limit_hit": telemetry.limit_hit,
			"steps_summary": str(current_step) + " / " + str(max_steps),
		}
		var gate = AISidebarCompletionPolicy.evaluate(gate_state)
		last_completion = gate
		if not text_content.is_empty() and context:
			context.add_assistant_message(text_content)
		if str(gate.get("verdict", "success")) == "success":
			_set_state(AgentState.COMPLETED, AISidebarI18n.get_text("status_ready"))
			_finish_task(true)
		else:
			print("[TIMING] %s | COMPLETION_GATE | verdict=%s reason=%s" % [get_ts(), str(gate.get("verdict", "")), str(gate.get("reason", ""))])
			_set_state(AgentState.ERROR, str(gate.get("reason", "")))
			error_occurred.emit(str(gate.get("reason", "")))
			_finish_task(false)

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

## Kalan kuyruk çağrılarını erteler: her birine açık DEFERRED sonucu yazılır
## (sessiz kayıp yok) ve tool_completed yayılır; körlemesine icra yapılmaz.
func _defer_remaining_calls(remaining: Array, code: String, message: String) -> void:
	if remaining.is_empty() or context == null:
		return
	for tc in remaining:
		var dname = str(tc.get("name", ""))
		var dargs = tc.get("arguments", {})
		var deferred = AISidebarToolResult.err(code, message + " (Araç: " + dname + ")", true)
		context.add_tool_result_message(str(tc.get("id", "call_default")), dname, deferred)
		unrecovered_failures[failure_key(dname, dargs if dargs is Dictionary else {})] = {"tool": dname, "deferred": true}
		tool_completed.emit(dname, deferred)

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
		telemetry.verification_checkpoints_count += 1

		var v_start = Time.get_ticks_msec()
		var verified_result = AISidebarVerificationPipeline.auto_verify_tool_execution(tool_name, args, res_dict)
		var v_delta = Time.get_ticks_msec() - v_start
		telemetry.verification_time_msec += v_delta

		is_valid = verified_result.get("success", false)
		ui_msg = verified_result.get("message", ui_msg)
		print("[TIMING] %s | VERIFICATION_DONE | tool=%s duration=%dms valid=%s" % [get_ts(), tool_name, v_delta, str(is_valid)])
		verification_completed.emit(tool_name, is_valid, ui_msg)

	return {"is_valid": is_valid, "message": ui_msg}

## Tek tool turunun kapanışı: sonuç context'e, vision kuyruğa (tur ilerletmez).
## Başarısızlık anahtarı: tool + hedef dosyalar (aynı işin retry'si eşleşir).
static func failure_key(tool_name: String, args: Dictionary) -> String:
	var targets: Array = []
	if args is Dictionary:
		for k in ["file_path", "scene_path"]:
			var v = str(args.get(k, "")).strip_edges()
			if not v.is_empty():
				targets.append(v)
	return str(tool_name) + "|" + ",".join(targets)

func _complete_tool_turn(tool_name: String, tool_call_id: String, args: Dictionary, result: Variant, is_valid: bool, ui_msg: String) -> void:
	var res_dict = result if result is Dictionary else {}
	# Recovery takibi: geçerli tur aynı anahtarı temizler.
	var fkey = failure_key(tool_name, args)
	if is_valid:
		unrecovered_failures.erase(fkey)
	else:
		unrecovered_failures[fkey] = {"tool": tool_name, "deferred": false}
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
		telemetry.note_retry()
		print("[TIMING] %s | PROVIDER_EMPTY_ERROR_RETRY | attempt=%d/%d" % [get_ts(), _empty_response_retry_count, max_empty_response_retries])
		_set_state(AgentState.RECOVERING, "Geçici ağ/boş yanıt hatası, tekrar deneniyor...")
		_run_next_step()
		return
		
	_set_state(AgentState.ERROR, error_message)
	print("[TIMING] %s | PROVIDER_ERROR | err=%s" % [get_ts(), error_message])
	error_occurred.emit(error_message)
	last_completion = {"verdict": "failed", "reason": error_message}
	_finish_task(false)
