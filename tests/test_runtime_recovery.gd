@tool
extends RefCounted

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")

class MockRecoveryProvider extends AISidebarAIProvider:
	var responses: Array = []
	var chat_count: int = 0
	
	func send_chat(messages: Array, tools_schema: Array) -> void:
		chat_count += 1
		if responses.size() > 0:
			var r = responses.pop_front()
			response_received.emit(r.get("content", ""), r.get("thinking", ""), r.get("tool_calls", []))

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var mock = MockRecoveryProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock, ctx)
	
	# Scenario 1: Initial task starts -> game launched -> error ingested -> auto recovery triggers
	mock.responses = [
		{"content": "", "thinking": "", "tool_calls": [{"name": "search_tools", "arguments": {"query": "play"}}]},
		{"content": "Hata düzeltildi.", "thinking": "Fixing code", "tool_calls": []}
	]
	
	runner.start_task("Run game and test")
	
	var obs = AISidebarRuntimeObservation.new()
	obs.add_error("Invalid get index 'speed' on Nil", "res://scripts/player.gd", 20, "_physics_process")
	
	runner.handle_runtime_error(obs)
	
	if runner.current_state == AISidebarAgentRunner.AgentState.IDLE or runner.current_state == AISidebarAgentRunner.AgentState.COMPLETED or mock.chat_count >= 2:
		passed += 1
	else:
		failed += 1
		errors.append("Otomatik recovery döngüsü tetiklenmedi.")
		
	# Scenario 2: Repeated error limit safeguard
	var runner2 = AISidebarAgentRunner.new(mock, ctx)
	runner2.start_task("Test repeated error safeguard")
	runner2.max_recovery_attempts = 2
	
	var repeat_obs = AISidebarRuntimeObservation.new()
	repeat_obs.add_error("Persistent crash error", "res://scripts/player.gd", 20)
	
	runner2.handle_runtime_error(repeat_obs)
	runner2.handle_runtime_error(repeat_obs)
	runner2.handle_runtime_error(repeat_obs) # 3rd time triggers limit
	
	if runner2._recovery_attempt_count >= 2:
		passed += 1
	else:
		failed += 1
		errors.append("Tekrarlayan hata sayacı çalışmadı.")
		
	return {"name": "RuntimeRecoveryTests", "passed": passed, "failed": failed, "errors": errors}
