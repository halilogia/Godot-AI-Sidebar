@tool
extends RefCounted

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var old_code = "func hello():\n\tprint('hi')"
	var new_code = "func hello():\n\tprint('hello world')"
	var cs = AISidebarChangeSet.new("res://scripts/Test.gd", AISidebarChangeSet.ChangeType.MODIFY_FILE, new_code, old_code, "Update greeting")
	
	var diff = cs.get_diff_text()
	if "--- a/res://scripts/Test.gd" in diff and "+ \tprint('hello world')" in diff and "- \tprint('hi')" in diff:
		passed += 1
	else:
		failed += 1
		errors.append("Diff generation failed:\n" + diff)
		
	return {"name": "ChangeSetTests", "passed": passed, "failed": failed, "errors": errors}
