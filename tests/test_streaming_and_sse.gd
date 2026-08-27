@tool
extends RefCounted

const AISidebarAgentRunner = preload("res://addons/godot_sidebar_ai/core/agent/agent_runner.gd")
const AISidebarAgentContext = preload("res://addons/godot_sidebar_ai/core/agent/agent_context.gd")
const AISidebarAIProvider = preload("res://addons/godot_sidebar_ai/core/providers/ai_provider.gd")
const AISidebarOpenAICompatibleProvider = preload("res://addons/godot_sidebar_ai/core/providers/openai_compatible_provider.gd")
const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarSSEParser = preload("res://addons/godot_sidebar_ai/core/network/sse_parser.gd")

class MockStreamingProvider extends AISidebarAIProvider:
	var chunks_to_stream: Array = []
	var final_response: Dictionary = {}
	
	func send_chat(_messages: Array, _tools_schema: Array) -> void:
		for ch in chunks_to_stream:
			chunk_received.emit(ch, "")
		response_received.emit(
			final_response.get("content", ""),
			final_response.get("thinking", ""),
			final_response.get("tool_calls", [])
		)

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: MessageBubble Akümülasyon ve Akış Tamamlama
	var bubble = AISidebarMessageBubble.new("assistant", "")
	bubble._ready()
	bubble.append_text("Merhaba ")
	bubble.append_text("dünya! ")
	bubble.append_text("res://test.gd dosyası.")
	if bubble.text_content == "Merhaba dünya! res://test.gd dosyası.":
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (MessageBubble append_text) failed: " + bubble.text_content)
		
	bubble.finalize_stream("Merhaba dünya! res://test.gd dosyası.")
	if "[url=file:res://test.gd]" in bubble._content_label.text:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (MessageBubble finalize_stream link format) failed.")
	bubble.queue_free()
	
	# Test 2: OpenAICompatibleProvider Incremental SSE Chunk Parsing
	var net = AISidebarNetworkManager.new()
	var provider = AISidebarOpenAICompatibleProvider.new(net)
	var accumulated_deltas: Array[String] = []
	provider.chunk_received.connect(func(t_delta, _th_delta):
		if not t_delta.is_empty():
			accumulated_deltas.append(t_delta)
	)
	
	# Parçalı SSE veri simülasyonu
	var chunk1 = "data: {\"choices\":[{\"delta\":{\"content\":\"Godot \"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"c"
	var chunk2 = "ontent\":\"4.7 \"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"harika!\"}}]}\n\ndata: [DONE]\n\n"
	
	provider._on_network_chunk("chat", chunk1)
	provider._on_network_chunk("chat", chunk2)
	
	var joined_text = "".join(accumulated_deltas)
	if joined_text == "Godot 4.7 harika!":
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (SSE chunk split & parse) failed. Got: '" + joined_text + "'")
	net.queue_free()
	
	# Test 3: AgentRunner Streaming Forwarding
	var mock_p = MockStreamingProvider.new()
	mock_p.chunks_to_stream = ["Adım 1: ", "Hazırlanıyor... ", "Bitti."]
	mock_p.final_response = {"content": "Adım 1: Hazırlanıyor... Bitti.", "thinking": "", "tool_calls": []}
	
	var ctx = AISidebarAgentContext.new()
	var runner = AISidebarAgentRunner.new(mock_p, ctx)
	
	var received_stream: Array[String] = []
	runner.chunk_received.connect(func(t, _th):
		if not t.is_empty():
			received_stream.append(t)
	)
	
	var task_done = [false]
	runner.task_completed.connect(func(_m): task_done[0] = true)
	
	runner.start_task("Test prompt")
	
	var runner_text = "".join(received_stream)
	if runner_text == "Adım 1: Hazırlanıyor... Bitti." and task_done[0]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (AgentRunner chunk_received forwarding) failed. Got: '" + runner_text + "'")
		
	# Test 4: Tool Calling with Streaming (Araç çağırma ve aktivite grubu uyumu)
	var mock_tool_p = MockStreamingProvider.new()
	mock_tool_p.chunks_to_stream = []
	mock_tool_p.final_response = {
		"content": "",
		"thinking": "",
		"tool_calls": [{
			"id": "call_1",
			"name": "analyze_project",
			"arguments": {}
		}]
	}
	
	var ctx2 = AISidebarAgentContext.new()
	var runner2 = AISidebarAgentRunner.new(mock_tool_p, ctx2)
	var executed_tools: Array[String] = []
	runner2.tool_executing.connect(func(fn, _a): executed_tools.append(fn))
	
	runner2.start_task("Proje analizi yap")
	
	if "analyze_project" in executed_tools:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (Tool calling during streaming) failed.")
		
	# Test 5: Fallback non-streaming response handling
	var static_res = "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"Non-streaming fallback yanıtı.\"},\"finish_reason\":\"stop\"}]}"
	var parsed_static = AISidebarSSEParser.parse_response(static_res)
	if parsed_static.get("content", "") == "Non-streaming fallback yanıtı.":
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (Non-streaming JSON fallback) failed.")
		
	return {"name": "StreamingAndSSETests", "passed": passed, "failed": failed, "errors": errors}
