@tool
extends RefCounted

const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Complete JSON Buffer + STATUS_CONNECTION_ERROR -> PASS
	var valid_json = "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"Tam yanıt\"}}]}"
	var b1 = valid_json.to_utf8_buffer()
	if AISidebarNetworkManager.is_buffer_complete(b1):
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (is_buffer_complete with valid JSON) failed.")
		
	# Test 2: SSE [DONE] Buffer + STATUS_CONNECTION_ERROR -> PASS
	var sse_done = "data: {\"choices\":[{\"delta\":{\"content\":\"selam\"}}]}\n\ndata: [DONE]\n\n"
	var b2 = sse_done.to_utf8_buffer()
	if AISidebarNetworkManager.is_buffer_complete(b2):
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (is_buffer_complete with SSE [DONE]) failed.")
		
	# Test 3: Valid SSE data stream Buffer without explicit [DONE] -> PASS
	var sse_chunks = "data: {\"choices\":[{\"delta\":{\"content\":\"Merhaba dünya\"}}]}\n\n"
	var b3 = sse_chunks.to_utf8_buffer()
	if AISidebarNetworkManager.is_buffer_complete(b3):
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (is_buffer_complete with valid SSE chunk) failed.")
		
	# Test 4: Partial / Incomplete JSON Buffer + STATUS_CONNECTION_ERROR -> FAIL
	var partial_json = "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"Yar"
	var b4 = partial_json.to_utf8_buffer()
	if not AISidebarNetworkManager.is_buffer_complete(b4):
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (is_buffer_complete rejected partial JSON) failed.")
		
	# Test 5: Empty Buffer + STATUS_CONNECTION_ERROR -> FAIL
	var empty_b = PackedByteArray()
	if not AISidebarNetworkManager.is_buffer_complete(empty_b):
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (is_buffer_complete rejected empty buffer) failed.")
		
	# Test 6: Content-Length satisfied -> PASS
	var cl_body = "Hello World".to_utf8_buffer()
	if AISidebarNetworkManager.is_buffer_complete(cl_body, 11):
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (is_buffer_complete Content-Length) failed.")
		
	# Test 7: NetworkManager State Machine Recovery Simulation
	var net = AISidebarNetworkManager.new()
	net._current_endpoint = "chat"
	net._is_request_active = true
	net._raw_response_body = valid_json.to_utf8_buffer()
	
	var completed_called = [false]
	var failed_called = [false]
	
	net.request_completed.connect(func(_ep, _code, resp):
		if resp == valid_json:
			completed_called[0] = true
	)
	net.request_failed.connect(func(_ep, _err):
		failed_called[0] = true
	)
	
	# Simulate STATUS_CONNECTION_ERROR recovery logic
	if AISidebarNetworkManager.is_buffer_complete(net._raw_response_body, net._expected_content_length):
		net._finalize_success()
	else:
		net.request_failed.emit(net._current_endpoint, "Ağ bağlantı hatası")
		
	if completed_called[0] and not failed_called[0]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (NetworkManager connection error recovery simulation) failed.")
		
	net.queue_free()
	
	return {"name": "NetworkRecoveryTests", "passed": passed, "failed": failed, "errors": errors}
