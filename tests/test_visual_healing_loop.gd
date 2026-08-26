@tool
extends RefCounted

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarVisualObservation = preload("res://addons/godot_sidebar_ai/core/types/visual_observation.gd")
const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")

class MockVisualProvider extends AISidebarAIProvider:
	var responses: Array = []
	
	func supports_vision() -> bool:
		return true
		
	func send_chat(messages: Array, tools_schema: Array) -> void:
		if responses.size() > 0:
			var r = responses.pop_front()
			response_received.emit(r.get("content", ""), r.get("thinking", ""), r.get("tool_calls", []))

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var mock = MockVisualProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock, ctx)
	
	# Scenario: Agent inspects scene visually -> mock provider returns camera fix -> completes
	mock.responses = [
		{"content": "", "thinking": "Oyuncu kamera dışında, FollowCamera ekliyorum.", "tool_calls": [{"name": "search_tools", "arguments": {"query": "camera"}}]},
		{"content": "Kamera başarıyla kuruldu.", "thinking": "Tamamlandı", "tool_calls": []}
	]
	
	runner.start_task("Diagnose camera position")
	
	var v_obs = AISidebarVisualObservation.new(null, "Oyuncu kamera dışında", 0.90)
	v_obs.add_issue("CAMERA_OUT_OF_BOUNDS", "Oyuncu ekran dışında")
	
	var v_verif = AISidebarVerificationPipeline.verify_visual_observation(v_obs)
	if v_verif.get("status") == AISidebarVerificationPipeline.VerificationStatus.FAILED:
		passed += 1
	else:
		failed += 1
		errors.append("Görsel anomali FAILED dönmedi.")
		
	if runner.current_state == AISidebarAgentRunner.AgentState.IDLE or runner.current_state == AISidebarAgentRunner.AgentState.COMPLETED:
		passed += 1
	else:
		failed += 1
		errors.append("Ajan görsel teşhis sonrası tamamlanamadı.")
		
	return {"name": "VisualHealingLoopTests", "passed": passed, "failed": failed, "errors": errors}
