@tool
extends RefCounted

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarChangeSetDialog = preload("res://addons/godot_sidebar_ai/ui/dialogs/change_set_dialog.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: undo_new_file_cleanup
	var test_new_f = "res://tests/temp_undo_new.gd"
	var cs_new = AISidebarChangeSet.new(test_new_f, AISidebarChangeSet.ChangeType.CREATE_FILE, "extends Node\nvar x = 1\n", "", "New file")
	var apply_res = cs_new.apply()
	
	if FileAccess.file_exists(test_new_f):
		var undo_res = cs_new.rollback()
		if undo_res.get("success", false) and not FileAccess.file_exists(test_new_f):
			passed += 1
		else:
			failed += 1
			errors.append("Test 1 (undo_new_file_cleanup) failed: File was not deleted on rollback: " + str(undo_res))
	else:
		failed += 1
		errors.append("Test 1 failed: apply could not create file: " + str(apply_res))
		
	# Test 2: undo_existing_file_restore
	var test_exist_f = "res://tests/temp_undo_exist.gd"
	var f_init = FileAccess.open(test_exist_f, FileAccess.WRITE)
	f_init.store_string("var initial_content = true\n")
	f_init.close()
	
	var cs_mod = AISidebarChangeSet.new(test_exist_f, AISidebarChangeSet.ChangeType.MODIFY_FILE, "var modified = true\n", "var initial_content = true\n", "Modify file")
	cs_mod.apply()
	
	var f_check1 = FileAccess.open(test_exist_f, FileAccess.READ)
	var txt1 = f_check1.get_as_text()
	f_check1.close()
	
	if "var modified = true" in txt1:
		cs_mod.rollback()
		var f_check2 = FileAccess.open(test_exist_f, FileAccess.READ)
		var txt2 = f_check2.get_as_text()
		f_check2.close()
		
		if "var initial_content = true" in txt2:
			passed += 1
		else:
			failed += 1
			errors.append("Test 2 (undo_existing_file_restore) failed: old content not restored: " + txt2)
	else:
		failed += 1
		errors.append("Test 2 failed: apply did not modify file.")
		
	if FileAccess.file_exists(test_exist_f):
		DirAccess.remove_absolute(test_exist_f)
		
	# Test 3: diff_dialog structure & sizing logic
	var dlg_scene = load("res://addons/godot_sidebar_ai/ui/dialogs/change_set_dialog.tscn")
	if dlg_scene:
		var dlg = dlg_scene.instantiate()
		var scroll = dlg.find_child("DiffScroll", true, false)
		if scroll is ScrollContainer and scroll.size_flags_vertical == Control.SIZE_EXPAND_FILL:
			passed += 1
		else:
			failed += 1
			errors.append("Test 3 (diff_dialog_scroll) failed: ScrollContainer with expand fill not found.")
		dlg.queue_free()
	else:
		failed += 1
		errors.append("Test 3 failed: change_set_dialog.tscn could not be loaded.")
		
	# Test 4: multi-file changeSet summary & deltas
	var cs_multi = AISidebarChangeSet.new("res://player.gd", AISidebarChangeSet.ChangeType.MODIFY_FILE, "var a = 1\nvar b = 2\n", "var a = 1\n", "update player")
	cs_multi.add_sub_change("res://Player.tscn", AISidebarChangeSet.ChangeType.CREATE_FILE, "[node name=\"P\"]\n", "", "new scene")
	cs_multi.add_sub_change("res://Level.tscn", AISidebarChangeSet.ChangeType.CREATE_FILE, "[node name=\"L\"]\n", "", "new level")
	
	var deltas = cs_multi.get_file_deltas()
	if deltas.size() == 3 and deltas[0]["file_name"] == "player.gd" and deltas[1]["file_name"] == "Player.tscn" and deltas[2]["file_name"] == "Level.tscn":
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 (multi_file_deltas) failed: " + str(deltas))
		
	return {"name": "UndoAndDialogUXTests", "passed": passed, "failed": failed, "errors": errors}
