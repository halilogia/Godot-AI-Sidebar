@tool
extends RefCounted
class_name AISidebarAgentRunner

## Otonom Ajan İcra Döngüsü, Hata Ayıklama & Otomatik İyileştirme Motoru (SRP).

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
signal verification_started(tool_name: String)
signal verification_completed(tool_name: String, is_valid: bool, msg: String)
signal runtime_observation_received(obs: AISidebarRuntimeObservation)
signal debugging_started(error_summary: String)
signal error_occurred(error_message: String)
signal loop_finished()

var provider: AISidebarAIProvider
var context: AISidebarAgentContext
var current_state: AgentState = AgentState.IDLE
var current_step: int = 0
var max_steps: int = 10
var max_recovery_attempts: int = 3
var _recovery_attempt_count: int = 0
var _last_error_signature: String = ""
var _last_tool_signature: String = ""
var _stagnation_count: int = 0

# Bekleyen Onay Verisi
var _pending_tool_name: String = ""
var _pending_tool_id: String = ""
var _pending_tool_args: Dictionary = {}
var _pending_change_set: AISidebarChangeSet = null
var runtime_debugger: AISidebarRuntimeDebugger = null

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
	max_steps = cfg.get("max_iterations", 10)
	current_step = 0
	_recovery_attempt_count = 0
	_last_error_signature = ""
	_last_tool_signature = ""
	_stagnation_count = 0
	_pending_tool_name = ""
	_pending_tool_id = ""
	_pending_tool_args = {}
	_pending_change_set = null
	
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
	loop_finished.emit()
	_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))

## Kullanıcı bekleyen işlemi onayladı (Approve)
func approve_pending_action() -> void:
	if current_state != AgentState.WAITING_FOR_APPROVAL or _pending_tool_name.is_empty():
		return
		
	var fn_name = _pending_tool_name
	var tc_id = _pending_tool_id
	var args = _pending_tool_args
	_pending_tool_name = ""
	_pending_tool_id = ""
	_pending_tool_args = {}
	_pending_change_set = null
	
	_set_state(AgentState.EXECUTING, "Onaylanan işlem çalıştırılıyor: " + fn_name)
	tool_executing.emit(fn_name, args)
	
	var result: Dictionary = AISidebarToolManager.execute_tool(fn_name, args, true)
	tool_completed.emit(fn_name, result)
	
	# Otomatik Doğrulama (Verification)
	_run_verification_and_proceed(fn_name, tc_id, args, result)

## Kullanıcı bekleyen işlemi reddetti (Reject)
func reject_pending_action(reason: String = "Kullanıcı bu işlemi reddetti.") -> void:
	if current_state != AgentState.WAITING_FOR_APPROVAL or _pending_tool_name.is_empty():
		return
		
	var fn_name = _pending_tool_name
	var tc_id = _pending_tool_id
	_pending_tool_name = ""
	_pending_tool_id = ""
	_pending_tool_args = {}
	_pending_change_set = null
	
	_set_state(AgentState.RECOVERING, "İşlem reddedildi, ajana bildiriliyor...")
	var reject_result = AISidebarToolResult.err("USER_REJECTED", reason, true)
	if context:
		context.add_tool_result_message(tc_id, fn_name, reject_result)
	
	_run_next_step()

## Çalışma zamanı hatası alındığında otomatik iyileştirme döngüsünü tetikler (Error -> Context -> Fix)
func handle_runtime_error(obs: AISidebarRuntimeObservation) -> void:
	if not is_running():
		return
		
	runtime_observation_received.emit(obs)
	
	var err_sig = ""
	if obs.errors.size() > 0:
		var e0 = obs.errors[0]
		err_sig = e0.get("file", "") + ":" + str(e0.get("line", 0)) + ":" + e0.get("message", "")
		
	# Tekrarlayan Hata Tespiti (Repeated Identical Error)
	if err_sig == _last_error_signature and not err_sig.is_empty():
		_recovery_attempt_count += 1
		if _recovery_attempt_count > max_recovery_attempts:
			_set_state(AgentState.ERROR, "Aynı çalışma zamanı hatası (" + str(_recovery_attempt_count) + " kez) çözülemedi. Müdahale bekleniyor.")
			error_occurred.emit("Otomatik iyileştirme limiti aşıldı: " + err_sig)
			loop_finished.emit()
			_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))
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
		loop_finished.emit()
		_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))
		return
		
	var status_msg = AISidebarI18n.get_text("status_thinking")
	if current_step > 1:
		status_msg = AISidebarI18n.get_text("status_executing", {"step": current_step, "max": max_steps})
		
	_set_state(AgentState.PLANNING, status_msg)
	
	var messages = context.get_messages_for_api()
	var tools_schema = AISidebarToolManager.get_all_schemas()
	provider.send_chat(messages, tools_schema)

func _on_provider_response(text_content: String, thinking_content: String, tool_calls: Array) -> void:
	if not is_running():
		return
		
	# Boş Yanıt Kontrolü (Empty Response Guard)
	if text_content.is_empty() and thinking_content.is_empty() and tool_calls.is_empty():
		_set_state(AgentState.ERROR, "Modelden boş yanıt alındı (Empty Response).")
		error_occurred.emit("Model boş yanıt döndürdü (PROVIDER_EMPTY_RESPONSE). Lütfen model seçimini, API adresini veya araç setini kontrol edin.")
		loop_finished.emit()
		_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))
		return
		
	# 1. Thinking (Düşünce Süreci)
	if not thinking_content.is_empty():
		thinking_received.emit(thinking_content)
		
	# 2. Metin Yanıtı
	if not text_content.is_empty():
		text_received.emit("assistant", text_content)
		
	# 3. Araç İcrası
	if tool_calls.size() > 0:
		# Assistant Tool Call mesajını OpenAI standartlarında bağlama ekle
		if context:
			context.add_assistant_tool_call_message(text_content, tool_calls)
			
		for tc in tool_calls:
			var fn_name: String = tc.get("name", "")
			var tc_id: String = tc.get("id", "call_default")
			var args: Dictionary = tc.get("arguments", {})
			
			# Stagnation / Erken Tekrarlama Koruması
			var sig = fn_name + ":" + JSON.stringify(args)
			if sig == _last_tool_signature:
				_stagnation_count += 1
				if _stagnation_count >= 2:
					_set_state(AgentState.ERROR, "Aynı araç (" + fn_name + ") tekrar tekrar çağrıldı. Döngü durduruldu.")
					error_occurred.emit("Ajan aynı aracı (" + fn_name + ") tekrarladı. Görev sonlandırıldı.")
					loop_finished.emit()
					_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))
					return
				else:
					# Modele ara uyarı gönder
					if context:
						context.add_user_message("SİSTEM BİLGİSİ: '" + fn_name + "' aracı zaten çalıştırıldı. Sonuç yukarıda mevcuttur. Lütfen aynı aracı tekrar çağırmadan yanıt verin.")
					_run_next_step()
					return
			else:
				_last_tool_signature = sig
				_stagnation_count = 0
				
			# Yetki ve Onay Kontrolü (Permission Check)
			_set_state(AgentState.EXECUTING, "Araç çalıştırılıyor: " + fn_name)
			tool_executing.emit(fn_name, args)
			
			var result: Dictionary = AISidebarToolManager.execute_tool(fn_name, args, false)
			
			# Eğer onay gerekiyorsa durakla ve WAITING_FOR_APPROVAL durumuna geç
			if not result.get("success", false) and result.get("error", {}).get("code", "") == "APPROVAL_REQUIRED":
				_pending_tool_name = fn_name
				_pending_tool_id = tc_id
				_pending_tool_args = args
				
				var cs: AISidebarChangeSet = null
				if fn_name == "create_or_update_script":
					var path = args.get("file_path", "")
					var old_c = ""
					if FileAccess.file_exists(path):
						var f = FileAccess.open(path, FileAccess.READ)
						if f:
							old_c = f.get_as_text()
							f.close()
					cs = AISidebarChangeSet.new(path, AISidebarChangeSet.ChangeType.MODIFY_FILE, args.get("content", ""), old_c, "Script güncellemesi")
				elif fn_name == "delete_node":
					cs = AISidebarChangeSet.new(args.get("node_path", ""), AISidebarChangeSet.ChangeType.MUTATE_SCENE, "", "", "Düğüm silme: " + args.get("node_path", ""))
					
				_pending_change_set = cs
				_set_state(AgentState.WAITING_FOR_APPROVAL, "Kullanıcı onayı bekleniyor (" + fn_name + ")")
				approval_requested.emit(fn_name, args, cs)
				return
				
			tool_completed.emit(fn_name, result)
			
			# Eğer araç oyunu başlattıysa runtime izleme durumuna geç
			if fn_name == "play_game" or fn_name == "restart_game":
				_set_state(AgentState.RUNNING_GAME, "Oyun çalışıyor, çalışma zamanı gözlemleniyor...")
				
			_run_verification_and_proceed(fn_name, tc_id, args, result)
			return
	else:
		# Araç çağrısı yok, model kullanıcıya nihai yanıtını verdi
		if not text_content.is_empty() and context:
			context.add_assistant_message(text_content)
			
		_set_state(AgentState.COMPLETED, AISidebarI18n.get_text("status_ready"))
		loop_finished.emit()
		_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))

func _run_verification_and_proceed(tool_name: String, tool_call_id: String, args: Dictionary, result: Variant) -> void:
	_set_state(AgentState.VERIFYING, "Doğrulanıyor: " + tool_name)
	verification_started.emit(tool_name)
	
	var res_dict = result if result is Dictionary else {}
	var verified_result = AISidebarVerificationPipeline.auto_verify_tool_execution(tool_name, args, res_dict)
	var is_valid = verified_result.get("success", false) if verified_result is Dictionary else true
	var msg = ""
	if verified_result is Dictionary:
		msg = verified_result.get("message", "")
		if msg.is_empty():
			var err_obj = verified_result.get("error")
			if err_obj is Dictionary and err_obj.has("message"):
				msg = err_obj["message"]
			elif err_obj is String:
				msg = err_obj
		
	verification_completed.emit(tool_name, is_valid, msg)
	
	_set_state(AgentState.OBSERVING, "Sonuçlar analiz ediliyor...")
	if context:
		var result_to_pass = verified_result if verified_result is Dictionary else {"data": result}
		context.add_tool_result_message(tool_call_id, tool_name, result_to_pass)
		
	_run_next_step()

func _on_provider_error(error_message: String) -> void:
	_set_state(AgentState.ERROR, error_message)
	error_occurred.emit(error_message)
	loop_finished.emit()
	_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))
