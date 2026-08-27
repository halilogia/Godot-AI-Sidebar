@tool
extends RefCounted

const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")
const AISidebarSSEParser = preload("res://addons/godot_sidebar_ai/core/network/sse_parser.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: SSE akışı [DONE] ile tamamlandı -> PASS (true)
	var sse_done = "data: {\"choices\":[{\"delta\":{\"content\":\"Merhaba \"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"dünya\"}}]}\n\ndata: [DONE]\n\n"
	if AISidebarNetworkManager.is_buffer_complete(sse_done.to_utf8_buffer()):
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (SSE with [DONE]) failed.")
		
	# Test 2: SSE finish_reason=stop (STATUS_BODY ve Soket Kapanışı) -> PASS (true)
	var sse_stop = "data: {\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}\n\ndata: {\"choices\":[{\"delta\":{\"content\":\"TEST_OK\"}}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"
	if AISidebarNetworkManager.is_buffer_complete(sse_stop.to_utf8_buffer(), -1, false) and \
	   AISidebarNetworkManager.is_buffer_complete(sse_stop.to_utf8_buffer(), -1, true):
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (SSE with finish_reason=stop) failed.")
		
	# Test 3: SSE tool_calls + finish_reason=tool_calls + connection close -> PASS (true)
	var sse_tool = "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_1\",\"function\":{\"name\":\"write_files\",\"arguments\":\"{\\\"files\\\":[]}\"}}]}}]}\n\ndata: {\"choices\":[{\"delta\":{},\"finish_reason\":\"tool_calls\"}]}\n\n"
	if AISidebarNetworkManager.is_buffer_complete(sse_tool.to_utf8_buffer(), -1, true):
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (SSE tool_calls with finish_reason=tool_calls) failed.")
		
	# Test 4: SSE veri akışı sırasında ara chunk (STATUS_BODY iken) -> Henüz bitmedi (false)
	var sse_mid_stream = "data: {\"choices\":[{\"delta\":{\"content\":\"Yazıyorum... \"}}]}\n\n"
	if not AISidebarNetworkManager.is_buffer_complete(sse_mid_stream.to_utf8_buffer(), -1, false):
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (SSE mid-stream in STATUS_BODY should not complete early) failed.")
		
	# Test 5: SSE veri akışı varken sunucu aniden soketi kapattı (Status 8) -> Veri kurtarılır (true)
	if AISidebarNetworkManager.is_buffer_complete(sse_mid_stream.to_utf8_buffer(), -1, true):
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (SSE mid-stream recovered on connection close) failed.")
		
	# Test 6: Sadece role-only chunk + STATUS_BODY -> Henüz bitmedi (false)
	var role_only = "data: {\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}\n\n"
	if not AISidebarNetworkManager.is_buffer_complete(role_only.to_utf8_buffer(), -1, false):
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (role-only in STATUS_BODY should not complete) failed.")
		
	# Test 7: Sadece role-only chunk + connection close -> FAIL / Boş sayılır (false)
	if not AISidebarNetworkManager.is_buffer_complete(role_only.to_utf8_buffer(), -1, true):
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (role-only on connection close must NOT be treated as success) failed.")
		
	# Test 8: Tamamen boş tampon + connection close -> FAIL (false)
	var empty_b = PackedByteArray()
	if not AISidebarNetworkManager.is_buffer_complete(empty_b, -1, true):
		passed += 1
	else:
		failed += 1
		errors.append("Test 8 (empty buffer on connection close should fail) failed.")
		
	# Test 9: Bozuk / Malformed SSE + connection close -> FAIL (false)
	var malformed = "data: {bozuk_json_data...".to_utf8_buffer()
	if not AISidebarNetworkManager.is_buffer_complete(malformed, -1, true):
		passed += 1
	else:
		failed += 1
		errors.append("Test 9 (malformed SSE on connection close should fail) failed.")
		
	# Test 10: Non-streaming geçerli JSON -> PASS (true)
	var valid_json = "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"Tam yanıt\"}}]}"
	if AISidebarNetworkManager.is_buffer_complete(valid_json.to_utf8_buffer()):
		passed += 1
	else:
		failed += 1
		errors.append("Test 10 (non-streaming valid JSON) failed.")
		
	# Test 11: Content-Length Karşılandı -> PASS (true)
	var cl_body = "Hello World".to_utf8_buffer()
	if AISidebarNetworkManager.is_buffer_complete(cl_body, 11):
		passed += 1
	else:
		failed += 1
		errors.append("Test 11 (Content-Length satisfied) failed.")
		
	# Test 12: Gerçek 9Router 3-Chunk SSE Formatı Parser Regresyon Testi
	var real_9router_stream = """data: {"id":"chatcmpl-1","choices":[{"delta":{"role":"assistant"},"finish_reason":null}]}

data: {"id":"chatcmpl-1","choices":[{"delta":{"content":"TEST_OK"},"finish_reason":null}]}

data: {"id":"chatcmpl-1","choices":[{"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":10,"completion_tokens":2}}
"""
	var parsed = AISidebarSSEParser.parse_response(real_9router_stream)
	if not parsed.has("error") and parsed.get("content", "") == "TEST_OK" and parsed.get("finish_reason", "") == "stop":
		passed += 1
	else:
		failed += 1
		errors.append("Test 12 (Real 9Router stream SSEParser test) failed: " + str(parsed))
		
	return {"name": "NetworkRecoveryTests", "passed": passed, "failed": failed, "errors": errors}
