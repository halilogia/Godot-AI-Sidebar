@tool
extends RefCounted

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Diff Generation
	var cs = AISidebarChangeSet.new("res://scripts/player.gd", AISidebarChangeSet.ChangeType.MODIFY_FILE, "var speed = 400.0\nvar jump = -500.0", "var speed = 300.0\nvar jump = -400.0", "Hız artırıldı")
	var diff = cs.get_diff_text()
	if "- var speed = 300.0" in diff and "+ var speed = 400.0" in diff:
		passed += 1
	else:
		failed += 1
		errors.append("Diff metni beklenen satırları içermiyor: " + diff)
		
	# Test 2: Apply & Rollback File Mutation
	var test_file = "res://tests/temp_test_file.gd"
	var cs_apply = AISidebarChangeSet.new(test_file, AISidebarChangeSet.ChangeType.CREATE_FILE, "var test = 123", "", "Geçici dosya")
	var apply_res = cs_apply.apply()
	if apply_res.get("success", false) and FileAccess.file_exists(test_file):
		passed += 1
		
		# Rollback test
		var rb_res = cs_apply.rollback()
		if rb_res.get("success", false) and not FileAccess.file_exists(test_file):
			passed += 1
		else:
			failed += 1
			errors.append("ChangeSet rollback başarısız oldu.")
	else:
		failed += 1
		errors.append("ChangeSet apply başarısız oldu: " + str(apply_res))
		
	return {"name": "ChangeSetTests", "passed": passed, "failed": failed, "errors": errors}
