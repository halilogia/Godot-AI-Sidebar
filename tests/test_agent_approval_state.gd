@tool
extends RefCounted

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")

class MockApprovalProvider extends AISidebarAIProvider:
	var responses: Array = []
	
	func send_chat(messages: Array, tools_schema: Array) -> void:
		if responses.size() > 0:
			var r = responses.pop_front()
			response_received.emit(r.get("content", ""), r.get("thinking", ""), r.get("tool_calls", []))

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var mock = MockApprovalProvider.new()
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock, ctx)
	
	# Scenario 1: Destructive tool requested -> Runner enters WAITING_FOR_APPROVAL
	mock.responses = [
		{"content": "", "thinking": "", "tool_calls": [{"name": "delete_node", "arguments": {"node_path": "TempNode"}}]},
		{"content": "Düğüm silindi ve işlem bitti.", "thinking": "", "tool_calls": []}
	]
	
	runner.start_task("Delete TempNode")
	
	if runner.current_state == AISidebarAgentRunner.AgentState.WAITING_FOR_APPROVAL:
		passed += 1
		
		# Now simulate user approval
		runner.approve_pending_action()
		
		if runner.current_state == AISidebarAgentRunner.AgentState.IDLE or runner.current_state == AISidebarAgentRunner.AgentState.COMPLETED:
			passed += 1
		else:
			failed += 1
			errors.append("Onay sonrası ajan tamamlanamadı: " + str(runner.current_state))
	else:
		failed += 1
		errors.append("Yıkıcı işlem sonrası WAITING_FOR_APPROVAL durumuna geçilmedi: " + str(runner.current_state))
		
	return {"name": "AgentApprovalStateTests", "passed": passed, "failed": failed, "errors": errors}
