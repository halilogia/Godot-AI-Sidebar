@tool
extends RefCounted

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Path Traversal
	var norm = AISidebarPathPolicy.normalize_path("res://scripts/../scenes/Player.tscn")
	if norm == "res://scenes/Player.tscn":
		passed += 1
	else:
		failed += 1
		errors.append("Path normalization failed: " + norm)
		
	# Test 2: Protected File (project.godot)
	var write_godot = AISidebarPathPolicy.is_safe_to_write("res://project.godot")
	if write_godot["safe"] == false:
		passed += 1
	else:
		failed += 1
		errors.append("Protected project.godot write was allowed!")
		
	# Test 3: Protected Addon Directory
	var write_addon = AISidebarPathPolicy.is_safe_to_write("res://addons/godot_sidebar_ai/plugin.gd")
	if write_addon["safe"] == false:
		passed += 1
	else:
		failed += 1
		errors.append("Protected addon write was allowed!")
		
	# Test 4: Safe Script Write
	var write_script = AISidebarPathPolicy.is_safe_to_write("res://scripts/Enemy.gd")
	if write_script["safe"] == true:
		passed += 1
	else:
		failed += 1
		errors.append("Safe script write was blocked: " + str(write_script))
		
	# Test 5: Adversarial Backslash & Traversal
	var adv_check = AISidebarPathPolicy.is_safe_to_write("res:\\foo\\..\\project.godot")
	if adv_check["safe"] == false:
		passed += 1
	else:
		failed += 1
		errors.append("Adversarial backslash traversal was allowed!")
		
	return {"name": "PathPolicyTests", "passed": passed, "failed": failed, "errors": errors}
