@tool
extends RefCounted

const AISidebarSSEParser = preload("res://addons/godot_sidebar_ai/core/network/sse_parser.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: SSE Stream with Reasoning & Content
	var sse_input = """data: {"choices":[{"delta":{"role":"assistant"}}]}

data: {"choices":[{"delta":{"reasoning_content":"Thinking about 2+2"}}]}

data: {"choices":[{"delta":{"content":"Result is 4."}}]}

data: [DONE]
"""
	var parsed = AISidebarSSEParser.parse_response(sse_input)
	if parsed.get("thinking", "") == "Thinking about 2+2" and parsed.get("content", "") == "Result is 4.":
		passed += 1
	else:
		failed += 1
		errors.append("SSE reasoning parse failed: " + str(parsed))
		
	# Test 2: Standard JSON Response with <think> tag
	var json_input = '{"choices":[{"message":{"content":"<think>Internal thought</think>Here is the code"}}]}'
	var parsed_json = AISidebarSSEParser.parse_response(json_input)
	if parsed_json.get("thinking", "") == "Internal thought" and parsed_json.get("content", "") == "Here is the code":
		passed += 1
	else:
		failed += 1
		errors.append("JSON think tag parse failed: " + str(parsed_json))
		
	return {"name": "SSEParserTests", "passed": passed, "failed": failed, "errors": errors}
