@tool
extends RefCounted
class_name AISidebarAgentRunner

## Otonom Ajan İcra Döngüsü ve Durum Makinesi (State Machine Agent Runner) (SRP).

const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarToolManager = preload("res://addons/godot_sidebar_ai/core/tools/tool_manager.gd")
const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

enum AgentState {
	IDLE,
	PLANNING,
	EXECUTING,
	OBSERVING,
	VERIFYING,
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
signal error_occurred(error_message: String)
signal loop_finished()

var provider: AISidebarAIProvider
var context: AISidebarAgentContext
var current_state: AgentState = AgentState.IDLE
var current_step: int = 0
var max_steps: int = 10
var _last_tool_signature: String = ""
var _stagnation_count: int = 0

func _init(p_provider: AISidebarAIProvider = null, p_context: AISidebarAgentContext = null) -> void:
	provider = p_provider
	context = p_context
	
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
	_last_tool_signature = ""
	_stagnation_count = 0
	
	context.add_user_message(user_prompt)
	text_received.emit("user", user_prompt)
	
	_set_state(AgentState.PLANNING, AISidebarI18n.get_text("status_thinking"))
	_run_next_step()

func stop() -> void:
	if not is_running():
		return
	if provider:
		provider.cancel()
	_set_state(AgentState.CANCELLED, AISidebarI18n.get_text("agent_stopped"))
	error_occurred.emit(AISidebarI18n.get_text("agent_stopped"))
	loop_finished.emit()
	_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))

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
		
	# 1. Thinking (Düşünce Süreci)
	if not thinking_content.is_empty():
		thinking_received.emit(thinking_content)
		
	# 2. Metin Yanıtı
	if not text_content.is_empty():
		if context:
			context.add_assistant_message(text_content)
		text_received.emit("assistant", text_content)
		
	# 3. Araç İcrası
	if tool_calls.size() > 0:
		_set_state(AgentState.EXECUTING, "Araçlar çalıştırılıyor...")
		
		for tc in tool_calls:
			var fn_name: String = tc.get("name", "")
			var args: Dictionary = tc.get("arguments", {})
			
			# Stagnation / Sonsuz Döngü Koruması
			var sig = fn_name + ":" + JSON.stringify(args)
			if sig == _last_tool_signature:
				_stagnation_count += 1
				if _stagnation_count >= 3:
					_set_state(AgentState.RECOVERING, "Tekrarlayan araç döngüsü tespit edildi, strateji değiştiriliyor.")
					if context:
						context.add_tool_result_message(fn_name, AISidebarToolResult.err("STAGNATION_DETECTED", "Aynı araç aynı parametrelerle 3 kez üst üste çağrıldı. Lütfen farklı bir yöntem veya açıklama deneyin."))
					_run_next_step()
					return
			else:
				_last_tool_signature = sig
				_stagnation_count = 0
				
			tool_executing.emit(fn_name, args)
			var result: Dictionary = AISidebarToolManager.execute_tool(fn_name, args)
			tool_completed.emit(fn_name, result)
			
			_set_state(AgentState.OBSERVING, "Sonuçlar analiz ediliyor...")
			if context:
				context.add_tool_result_message(fn_name, result)
			
		# Bir sonraki adıma geç
		_run_next_step()
	else:
		# Araç çağrısı bitti, görev tamamlandı
		_set_state(AgentState.COMPLETED, AISidebarI18n.get_text("status_ready"))
		loop_finished.emit()
		_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))

func _on_provider_error(error_message: String) -> void:
	_set_state(AgentState.ERROR, error_message)
	error_occurred.emit(error_message)
	loop_finished.emit()
	_set_state(AgentState.IDLE, AISidebarI18n.get_text("status_ready"))
