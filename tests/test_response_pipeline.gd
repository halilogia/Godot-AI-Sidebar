@tool
extends RefCounted

const AISidebarSSEParser = preload("res://addons/godot_sidebar_ai/core/network/sse_parser.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Text-only Streaming (SSE)
	var sse_text_chunks = """data: {"choices":[{"delta":{"content":"Merhaba "},"index":0}]}
data: {"choices":[{"delta":{"content":"Dünya!"},"index":0}]}
data: [DONE]
"""
	var res_stream_text = AISidebarSSEParser.parse_response(sse_text_chunks)
	if res_stream_text.get("content", "") == "Merhaba Dünya!" and res_stream_text.get("tool_calls", []).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("Text-only streaming parse başarısız: " + str(res_stream_text))
		
	# Test 2: Text-only Non-Streaming (Standard JSON)
	var json_text = '{"choices":[{"message":{"role":"assistant","content":"4"}}]}'
	var res_json_text = AISidebarSSEParser.parse_response(json_text)
	if res_json_text.get("content", "") == "4":
		passed += 1
	else:
		failed += 1
		errors.append("Text-only non-streaming parse başarısız: " + str(res_json_text))
		
	# Test 3: Single-tool Streaming (Multi-chunk SSE tool_calls)
	var sse_tool_chunks = """data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_123","function":{"name":"create_scene","arguments":""}}]},"index":0}]}
data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\\"scene_path\\":"}}]},"index":0}]}
data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\\"res://test.tscn\\"}"}}]},"index":0}]}
data: {"choices":[{"delta":{},"finish_reason":"tool_calls","index":0}]}
data: [DONE]
"""
	var res_stream_tool = AISidebarSSEParser.parse_response(sse_tool_chunks)
	var tools_stream = res_stream_tool.get("tool_calls", [])
	if tools_stream.size() == 1 and tools_stream[0].get("name", "") == "create_scene" and tools_stream[0].get("arguments", {}).get("scene_path", "") == "res://test.tscn":
		passed += 1
	else:
		failed += 1
		errors.append("Single-tool streaming parse başarısız: " + str(res_stream_tool))
		
	# Test 4: Single-tool Non-Streaming (Direct JSON tool_calls)
	var json_tool = '{"choices":[{"message":{"role":"assistant","tool_calls":[{"id":"call_456","function":{"name":"add_node","arguments":"{\\"node_type\\":\\"Node2D\\",\\"node_name\\":\\"Player\\"}"}}]}}]}'
	var res_json_tool = AISidebarSSEParser.parse_response(json_tool)
	var tools_json = res_json_tool.get("tool_calls", [])
	if tools_json.size() == 1 and tools_json[0].get("name", "") == "add_node" and tools_json[0].get("arguments", {}).get("node_type", "") == "Node2D":
		passed += 1
	else:
		failed += 1
		errors.append("Single-tool non-streaming parse başarısız: " + str(res_json_tool))
		
	# Test 5: Empty Response Guard
	var empty_sse = "data: [DONE]\n"
	var res_empty = AISidebarSSEParser.parse_response(empty_sse)
	if res_empty.has("error") and "PROVIDER_EMPTY_RESPONSE" in str(res_empty["error"]):
		passed += 1
	else:
		failed += 1
		errors.append("Empty response guard başarısız: " + str(res_empty))
		
	return {"name": "ResponsePipelineTests", "passed": passed, "failed": failed, "errors": errors}
