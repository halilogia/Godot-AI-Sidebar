@tool
extends RefCounted

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")

class MockToolCallingProvider extends AISidebarAIProvider:
	var response_queue: Array = []
	var recorded_messages: Array = []
	
	func send_chat(messages: Array, tools_schema: Array) -> void:
		recorded_messages.append(messages.duplicate(true))
		if response_queue.size() > 0:
			var r = response_queue.pop_front()
			response_received.emit(
				r.get("content", ""),
				r.get("thinking", ""),
				r.get("tool_calls", [])
			)

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Single-Tool Question Terminates Naturally (1 tool -> result -> final answer)
	var mock1 = MockToolCallingProvider.new()
	var ctx1 = AISidebarAgentContext.new()
	var runner1 = AISidebarAgentRunner.new(mock1, ctx1)
	
	mock1.response_queue = [
		# Adım 1: Model analyze_project aracını çağırır
		{
			"content": "",
			"thinking": "Ana sahneyi öğrenmek için projeyi analiz ediyorum.",
			"tool_calls": [{"id": "call_scene_999", "name": "analyze_project", "arguments": {}}]
		},
		# Adım 2: Model tool sonucunu aldıktan sonra nihai metin yanıtını verir
		{
			"content": "Projenin ana sahnesi res://main.tscn olarak ayarlanmıştır.",
			"thinking": "Bilgiyi aldım, kullanıcıya yanıt veriyorum.",
			"tool_calls": []
		}
	]
	
	var received_answers: Array = []
	runner1.text_received.connect(func(role, txt):
		if role == "assistant":
			received_answers.append(txt)
	)
	
	runner1.start_task("Projenin ana sahnesinin adını söyle.")
	
	# Doğrulama 1: Runner COMPLETED veya IDLE olmalı ve 2 adım sürmüş olmalı
	if mock1.recorded_messages.size() == 2 and received_answers.size() == 1:
		passed += 1
	else:
		failed += 1
		errors.append("Single-tool termination başarısız: steps=" + str(mock1.recorded_messages.size()) + ", answers=" + str(received_answers.size()))
		
	# Doğrulama 2: İkinci adımda gönderilen mesajlarda assistant tool_calls ve role=tool (tool_call_id) bulunmalı
	var step2_msgs = mock1.recorded_messages[1]
	var has_tool_role = false
	var has_matching_call_id = false
	for m in step2_msgs:
		if m.get("role") == "tool":
			has_tool_role = true
			if m.get("tool_call_id") == "call_scene_999":
				has_matching_call_id = true
				
	if has_tool_role and has_matching_call_id:
		passed += 1
	else:
		failed += 1
		errors.append("Tool result mesajı standart formatta iletilmedi: role_tool=" + str(has_tool_role) + ", id_match=" + str(has_matching_call_id))
		
	# Test 2: Erken Tekrarlama Koruması (Stagnation Guard)
	var mock2 = MockToolCallingProvider.new()
	var ctx2 = AISidebarAgentContext.new()
	var runner2 = AISidebarAgentRunner.new(mock2, ctx2)
	
	# Model aynı aracı aynı parametrelerle üst üste 3 kez çağırmaya çalışsın
	mock2.response_queue = [
		{"content": "", "thinking": "", "tool_calls": [{"id": "call_1", "name": "analyze_project", "arguments": {}}]},
		{"content": "", "thinking": "", "tool_calls": [{"id": "call_2", "name": "analyze_project", "arguments": {}}]},
		{"content": "", "thinking": "", "tool_calls": [{"id": "call_3", "name": "analyze_project", "arguments": {}}]}
	]
	
	runner2.start_task("Test stagnation")
	
	if runner2.current_state == AISidebarAgentRunner.AgentState.IDLE or runner2.current_state == AISidebarAgentRunner.AgentState.ERROR:
		passed += 1
	else:
		failed += 1
		errors.append("Stagnation guard döngüyü durduramadı.")
		
	return {"name": "ToolTerminationTests", "passed": passed, "failed": failed, "errors": errors}
