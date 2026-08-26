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

enum AgentState {
	IDLE,
	PLANNING,
	EXECUTING,
	OBSERVING,
	VERIFYING,
	WAITING_FOR_APPROVAL,
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
signal text_received(role: String, message_text: String)
signal tool_executing(tool_name: String, args: Dictionary)
signal tool_completed(tool_name: String, result: Dictionary)
signal approval_requested(tool_name: String, args: Dictionary, change_set: AISidebarChangeSet)
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

var llm_time_msec: int = 0
var tool_time_msec: int = 0
var file_time_msec: int = 0
var editor_time_msec: int = 0
var runtime_time_msec: int = 0
var verification_time_msec: int = 0
var waiting_time_msec: int = 0

# Bekleyen Onay Verisi
var _pending_tool_name: String = ""
var _pending_tool_id: String = ""
var _pending_tool_args: Dictionary = {}
var _pending_change_set: AISidebarChangeSet = null
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
		provider.error_occurred.connect(_on_provider_error)

func is_running() -> bool:
	return current_state != AgentState.IDLE and current_state != AgentState.COMPLETED and current_state != AgentState.ERROR and current_state != AgentState.CANCELLED

func _set_state(new_state: AgentState, desc: String = "") -> void:
	current_state = new_state
	state_changed.emit(new_state, desc)

func start_task(user_prompt: String) -> void:
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
	
	# Telemetri Sıfırlama
	task_start_time_msec = Time.get_ticks_msec()
	llm_turns_count = 0
	tool_calls_count = 0
	file_ops_count = 0
	editor_ops_count = 0
	runtime_ops_count = 0
	verification_checkpoints_count = 0
	
	llm_time_msec = 0
	tool_time_msec = 0
	file_time_msec = 0
	editor_time_msec = 0
	runtime_time_msec = 0
	verification_time_msec = 0
	waiting_time_msec = 0
	
	print("[TIMING] %s | TASK_START | prompt=%s" % [get_ts(), user_prompt.left(60)])
	context.add_user_message(user_prompt)
	text_received.emit("user", user_prompt)
	
	_set_state(AgentState.PLANNING, AISidebarI18n.get_text("status_thinking"))
	_run_next_step()

func stop() -> void:
	if not is_running():
		return
	if provider:
		provider.cancel()
	if runtime_debugger:
		runtime_debugger.stop()
		
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
		# Detaylı Süre Dağılımı (Saniye)
		"llm_time_s": snappedf(llm_time_msec / 1000.0, 0.1),
		"tool_time_s": snappedf(tool_time_msec / 1000.0, 0.1),
		"file_time_s": snappedf(file_time_msec / 1000.0, 0.1),
		"editor_time_s": snappedf(editor_time_msec / 1000.0, 0.1),
		"runtime_time_s": snappedf(runtime_time_msec / 1000.0, 0.1),
		"verification_time_s": snappedf(verification_time_msec / 1000.0, 0.1),
		"waiting_time_s": snappedf(waiting_time_msec / 1000.0, 0.1)
	}
	print("[TIMING] %s | TASK_COMPLETE | success=%s elapsed=%.3fs llm=%.3fs tool=%.3fs" % [get_ts(), str(success), total_elapsed_sec, llm_time_msec / 1000.0, tool_time_msec / 1000.0])
	task_completed.emit(metrics)
	loop_finished.emit()
	_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))

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
	var result: Dictionary = AISidebarToolManager.execute_tool(fn_name, args, true)
	var t_delta = Time.get_ticks_msec() - t_start
	tool_time_msec += t_delta
	_record_category_time(fn_name, t_delta)
	
	print("[TIMING] %s | TOOL_DONE (APPROVED) | tool=%s duration=%dms" % [get_ts(), fn_name, t_delta])
	if not fn_name in _unlocked_tools:
		_unlocked_tools.append(fn_name)
	tool_completed.emit(fn_name, result)
	if cs and result.get("success", false):
		changes_applied.emit(cs)
		
	_run_verification_and_proceed(fn_name, tc_id, args, result)

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
	if current_step > max_steps:
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
				
	var tools_schema = AISidebarToolManager.get_relevant_schemas(context_text, _unlocked_tools)
	last_tools_sent_count = tools_schema.size()
	
	if current_step > 1:
		print("[TIMING] %s | NEXT_LLM_REQUEST_START | step=%d/%d tools=%d/%d" % [get_ts(), current_step, max_steps, last_tools_sent_count, AISidebarToolManager.get_all_schemas().size()])
	else:
		print("[TIMING] %s | LLM_REQUEST_START | step=1/%d tools=%d/%d" % [get_ts(), max_steps, last_tools_sent_count, AISidebarToolManager.get_all_schemas().size()])
		
	var messages = context.get_messages_for_api()
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
			context.add_assistant_tool_call_message(text_content, tool_calls)
			
		for tc in tool_calls:
			var fn_name: String = tc.get("name", "")
			var tc_id: String = tc.get("id", "call_default")
			var args: Dictionary = tc.get("arguments", {})
			
			tool_calls_count += 1
			_classify_telemetry_op(fn_name, args)
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
					_run_next_step()
					return
			else:
				_last_tool_signature = sig
				_stagnation_count = 0
				
			# Değişiklik Öncesi Eski İçerikleri Kaydet (ChangeSet Hazırlığı)
			var cs = _build_changeset_for_tool(fn_name, args)
			
			# Yetki ve Onay Kontrolü
			_set_state(AgentState.EXECUTING, "Araç çalıştırılıyor: " + fn_name)
			print("[TIMING] %s | TOOL_START | tool=%s" % [get_ts(), fn_name])
			tool_executing.emit(fn_name, args)
			
			var t_start = Time.get_ticks_msec()
			var result: Dictionary = AISidebarToolManager.execute_tool(fn_name, args, false)
			var t_delta = Time.get_ticks_msec() - t_start
			tool_time_msec += t_delta
			_record_category_time(fn_name, t_delta)
			
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
				approval_requested.emit(fn_name, args, cs)
				return
				
			tool_completed.emit(fn_name, result)
			if cs and result.get("success", false):
				changes_applied.emit(cs)
				
			if fn_name == "play_game" or fn_name == "restart_game":
				_set_state(AgentState.RUNNING_GAME, "Oyun çalışıyor...")
				
			_run_verification_and_proceed(fn_name, tc_id, args, result)
			return
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

func _classify_telemetry_op(fn_name: String, args: Dictionary) -> void:
	match fn_name:
		"create_or_update_script", "create_scene", "save_scene":
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

func _run_verification_and_proceed(tool_name: String, tool_call_id: String, args: Dictionary, result: Variant) -> void:
	var res_dict = result if result is Dictionary else {}
	var is_valid = res_dict.get("success", false)
	var ui_msg = res_dict.get("message", "")
	
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
		
	print("[TIMING] %s | AGENT_CONTINUE | next_step=%d" % [get_ts(), current_step + 1])
	_run_next_step()

func _on_provider_error(error_message: String) -> void:
	if not is_running():
		return
		
	if ("PROVIDER_EMPTY_RESPONSE" in error_message or "boş yanıt" in error_message) and _empty_response_retry_count < max_empty_response_retries:
		_empty_response_retry_count += 1
		print("[TIMING] %s | PROVIDER_EMPTY_ERROR_RETRY | attempt=%d/%d" % [get_ts(), _empty_response_retry_count, max_empty_response_retries])
		_set_state(AgentState.RECOVERING, "Geçici ağ/boş yanıt hatası, tekrar deneniyor...")
		_run_next_step()
		return
		
	_set_state(AgentState.ERROR, error_message)
	print("[TIMING] %s | PROVIDER_ERROR | err=%s" % [get_ts(), error_message])
	error_occurred.emit(error_message)
	_finish_task(false)
