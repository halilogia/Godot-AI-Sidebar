@tool
extends SceneTree

func _init() -> void:
	print("==================================================")
	print("   GODOT AI CORE v2.0 - HEADLESS UNIT TESTS      ")
	print("==================================================")
	
	var all_suites = [
		load("res://tests/test_type_parser.gd"),
		load("res://tests/test_path_policy.gd"),
		load("res://tests/test_change_set.gd"),
		load("res://tests/test_sse_parser.gd"),
		load("res://tests/test_tool_manager.gd"),
		load("res://tests/test_agent_context.gd"),
		load("res://tests/test_agent_runner_state.gd")
	]
	
	var total_passed = 0
	var total_failed = 0
	
	for suite in all_suites:
		if suite:
			var res = suite.run()
			var name = res.get("name", "Suite")
			var p = res.get("passed", 0)
			var f = res.get("failed", 0)
			total_passed += p
			total_failed += f
			
			if f == 0:
				print(" [PASS] " + name + " (" + str(p) + "/" + str(p) + " passed)")
			else:
				print(" [FAIL] " + name + " (" + str(p) + " passed, " + str(f) + " FAILED)")
				for err in res.get("errors", []):
					print("        ❌ " + str(err))
					
	print("--------------------------------------------------")
	if total_failed == 0:
		print("🎉 ALL TESTS PASSED! Total: " + str(total_passed) + " assertions.")
		quit(0)
	else:
		print("❌ TEST SUITE FAILED: " + str(total_failed) + " failures.")
		quit(1)
