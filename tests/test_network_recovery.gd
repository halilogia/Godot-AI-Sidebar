@tool
extends RefCounted

const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")
const AISidebarSSEParser = preload("res://addons/godot_sidebar_ai/core/network/sse_parser.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: İlk boş SSE chunk (role definition only) -> Tamamlanmamalı (false)
	var first_empty_chunk = "data: {\"choices\":[{\"delta\":{\"role\":\"assistant\",\"content\":\"\"}}]}\n\n"
	var b1 = first_empty_chunk.to_utf8_buffer()
	if not AISidebarNetworkManager.is_buffer_complete(b1):
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (first empty SSE chunk should NOT be complete) failed.")
		
	# Test 2: İlk metin chunk'ı -> Tamamlanmamalı (false)
	var first_text_chunk = "data: {\"choices\":[{\"delta\":{\"content\":\"Merhaba\"}}]}\n\n"
	var b2 = first_text_chunk.to_utf8_buffer()
	if not AISidebarNetworkManager.is_buffer_complete(b2):
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (first content SSE chunk should NOT be complete) failed.")
		
	# Test 3: Birden fazla SSE chunk'ı ([DONE] olmadan) -> Tamamlanmamalı (false)
	var multi_chunks = "data: {\"choices\":[{\"delta\":{\"content\":\"Merhaba \"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"dünya\"}}]}\n\n"
	var b3 = multi_chunks.to_utf8_buffer()
	if not AISidebarNetworkManager.is_buffer_complete(b3):
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (multiple SSE chunks without [DONE] should NOT be complete) failed.")
		
	# Test 4: SSE akışı [DONE] ile tamamlandı -> Tamamlanmalı (true)
	var sse_done = multi_chunks + "data: [DONE]\n\n"
	var b4 = sse_done.to_utf8_buffer()
	if AISidebarNetworkManager.is_buffer_complete(b4):
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (SSE stream with [DONE] should be complete) failed.")
		
	# Test 5: Tool-call SSE chunk'ları ([DONE] olmadan) -> Tamamlanmamalı (false)
	var tool_chunks = "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_1\",\"function\":{\"name\":\"write_files\",\"arguments\":\"{\\\"files\\\":[]}\"}}]}}]}\n\n"
	var b5 = tool_chunks.to_utf8_buffer()
	if not AISidebarNetworkManager.is_buffer_complete(b5):
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (tool call SSE chunks without [DONE] should NOT be complete) failed.")
		
	# Test 6: Tool-call SSE chunk'ları [DONE] ile -> Tamamlanmalı (true)
	var tool_done = tool_chunks + "data: [DONE]\n\n"
	var b6 = tool_done.to_utf8_buffer()
	if AISidebarNetworkManager.is_buffer_complete(b6):
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (tool call SSE chunks with [DONE] should be complete) failed.")
		
	# Test 7: Non-streaming JSON -> Tamamlanmalı (true)
	var valid_json = "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"Tam yanıt\"}}]}"
	var b7 = valid_json.to_utf8_buffer()
	if AISidebarNetworkManager.is_buffer_complete(b7):
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (non-streaming JSON should be complete) failed.")
		
	# Test 8: Partial / Incomplete JSON -> Tamamlanmamalı (false)
	var partial_json = "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"Yar"
	var b8 = partial_json.to_utf8_buffer()
	if not AISidebarNetworkManager.is_buffer_complete(b8):
		passed += 1
	else:
		failed += 1
		errors.append("Test 8 (partial JSON should NOT be complete) failed.")
		
	# Test 9: Empty buffer -> Tamamlanmamalı (false)
	var empty_b = PackedByteArray()
	if not AISidebarNetworkManager.is_buffer_complete(empty_b):
		passed += 1
	else:
		failed += 1
		errors.append("Test 9 (empty buffer should NOT be complete) failed.")
		
	# Test 10: Content-Length satisfied -> Tamamlanmalı (true)
	var cl_body = "Hello World".to_utf8_buffer()
	if AISidebarNetworkManager.is_buffer_complete(cl_body, 11):
		passed += 1
	else:
		failed += 1
		errors.append("Test 10 (Content-Length satisfied should be complete) failed.")
		
	# Test 11: SSEParser Regression Test (Full stream produces non-empty result)
	var parsed = AISidebarSSEParser.parse_response(sse_done)
	if not parsed.has("error") and parsed.get("content", "") == "Merhaba dünya":
		passed += 1
	else:
		failed += 1
		errors.append("Test 11 (SSEParser correctly parsed full stream) failed: " + str(parsed))
		
	return {"name": "NetworkRecoveryTests", "passed": passed, "failed": failed, "errors": errors}
