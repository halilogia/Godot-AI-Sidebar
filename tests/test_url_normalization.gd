@tool
extends RefCounted

const AISidebarNetworkManager = preload("res://addons/godot_sidebar_ai/core/network/network_manager.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: localhost:20128 -> 127.0.0.1:20128
	var p1 = AISidebarNetworkManager.parse_url("http://localhost:20128/v1")
	if p1["host"] == "127.0.0.1" and p1["port"] == 20128 and p1["path"] == "/v1" and not p1["ssl"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (localhost:20128) failed: " + str(p1))
		
	# Test 2: localhost -> 127.0.0.1 (default port 80)
	var p2 = AISidebarNetworkManager.parse_url("http://localhost")
	if p2["host"] == "127.0.0.1" and p2["port"] == 80 and p2["path"] == "/" and not p2["ssl"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (localhost default) failed: " + str(p2))
		
	# Test 3: localhost.localdomain:8080 -> 127.0.0.1:8080
	var p3 = AISidebarNetworkManager.parse_url("http://localhost.localdomain:8080/api")
	if p3["host"] == "127.0.0.1" and p3["port"] == 8080 and p3["path"] == "/api" and not p3["ssl"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (localhost.localdomain) failed: " + str(p3))
		
	# Test 4: 127.0.0.1:20128 -> unchanged
	var p4 = AISidebarNetworkManager.parse_url("http://127.0.0.1:20128/v1")
	if p4["host"] == "127.0.0.1" and p4["port"] == 20128 and p4["path"] == "/v1" and not p4["ssl"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (127.0.0.1) failed: " + str(p4))
		
	# Test 5: example.com -> unchanged
	var p5 = AISidebarNetworkManager.parse_url("http://example.com/v1")
	if p5["host"] == "example.com" and p5["port"] == 80 and p5["path"] == "/v1" and not p5["ssl"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (example.com) failed: " + str(p5))
		
	# Test 6: [::1]:20128 -> unchanged (IPv6 literal)
	var p6 = AISidebarNetworkManager.parse_url("http://[::1]:20128/v1")
	if p6["host"] == "[::1]" and p6["port"] == 20128 and p6["path"] == "/v1" and not p6["ssl"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 (IPv6 literal [::1]) failed: " + str(p6))
		
	# Test 7: https://example.com/v1 -> unchanged, ssl: true, default port 443
	var p7 = AISidebarNetworkManager.parse_url("https://example.com/v1")
	if p7["host"] == "example.com" and p7["port"] == 443 and p7["path"] == "/v1" and p7["ssl"]:
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 (https://example.com/v1) failed: " + str(p7))
		
	return {"name": "URLNormalizationTests", "passed": passed, "failed": failed, "errors": errors}
