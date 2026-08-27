@tool
extends RefCounted

const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var test_file = "res://temp_surgical_test.gd"
	
	# Hazırlık: Test dosyasını oluştur
	var initial_code = """extends Node2D

var speed = 5.0
var jump_force = -400.0

func _ready() -> void:
	print("Ready")

func move() -> void:
	position.x += speed
"""
	var f = FileAccess.open(test_file, FileAccess.WRITE)
	f.store_string(initial_code)
	f.close()
	
	# Test 1: Tek eşleşme → Başarılı cerrahi değişim, diff ve hash doğrulaması
	var res1 = AISidebarScriptTools.execute("replace_file_content", {
		"file_path": test_file,
		"target_code": "var speed = 5.0",
		"replacement_code": "var speed = 8.0"
	})
	
	if res1.get("success", false) and res1.get("data", {}).get("replacements", 0) == 1:
		var f_check = FileAccess.open(test_file, FileAccess.READ)
		var c_check = f_check.get_as_text()
		f_check.close()
		if "var speed = 8.0" in c_check and not "var speed = 5.0" in c_check and "var jump_force = -400.0" in c_check:
			passed += 1
		else:
			failed += 1
			errors.append("Test 1 failed: file content not properly modified: " + c_check)
	else:
		failed += 1
		errors.append("Test 1 failed: " + str(res1))
		
	# Test 2: Eşleşme yok (0 match) → TARGET_NOT_FOUND hatası, dosya değişmemeli
	var res2 = AISidebarScriptTools.execute("replace_file_content", {
		"file_path": test_file,
		"target_code": "non_existent_code_line()",
		"replacement_code": "new_code()"
	})
	if not res2.get("success", true) and res2.get("error", {}).get("code", "") == "TARGET_NOT_FOUND":
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (TARGET_NOT_FOUND) failed: " + str(res2))
		
	# Test 3: Birden fazla eşleşme (>1 match) → MULTIPLE_TARGETS_FOUND hatası
	var multi_file = "res://temp_multi_target_test.gd"
	var multi_code = """extends Node
func a():
	print("Duplicate")
func b():
	print("Duplicate")
"""
	var f_m = FileAccess.open(multi_file, FileAccess.WRITE)
	f_m.store_string(multi_code)
	f_m.close()
	
	var res3 = AISidebarScriptTools.execute("replace_file_content", {
		"file_path": multi_file,
		"target_code": "print(\"Duplicate\")",
		"replacement_code": "print(\"Fixed\")"
	})
	if not res3.get("success", true) and res3.get("error", {}).get("code", "") == "MULTIPLE_TARGETS_FOUND":
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 (MULTIPLE_TARGETS_FOUND) failed: " + str(res3))
	DirAccess.remove_absolute(multi_file)
	
	# Test 4: Sözdizimi hatalı replacement → SCRIPT_SYNTAX_ERROR ve dosya değişmez
	var res4 = AISidebarScriptTools.execute("replace_file_content", {
		"file_path": test_file,
		"target_code": "var speed = 8.0",
		"replacement_code": "var speed = ::: invalid syntax"
	})
	if not res4.get("success", true) and res4.get("error", {}).get("code", "") == "SCRIPT_SYNTAX_ERROR":
		var f_check4 = FileAccess.open(test_file, FileAccess.READ)
		var c_check4 = f_check4.get_as_text()
		f_check4.close()
		if "var speed = 8.0" in c_check4:
			passed += 1
		else:
			failed += 1
			errors.append("Test 4 failed: file was modified despite syntax error")
	else:
		failed += 1
		errors.append("Test 4 (SCRIPT_SYNTAX_ERROR) failed: " + str(res4))
		
	# Test 5: PermissionPolicy entegrasyonu (Mevcut dosya için overwrite onayı istemeli)
	var req_appr = AISidebarPermissionPolicy.requires_user_approval("replace_file_content", {"file_path": test_file})
	if req_appr == true:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 (PermissionPolicy) failed: requires_user_approval returned " + str(req_appr))
		
	# Test 6: Diff üretimi ve Undo (Rollback) eski içeriği eksiksiz geri getirmeli
	var res6 = AISidebarScriptTools.execute("replace_file_content", {
		"file_path": test_file,
		"target_code": "var speed = 8.0",
		"replacement_code": "var speed = 15.0"
	})
	if res6.get("success", false) and res6.has("change_set"):
		var cs: AISidebarChangeSet = res6["change_set"]
		var diff_str = cs.get_diff_text()
		if ("- var speed = 8.0" in diff_str or "-var speed = 8.0" in diff_str) and ("+ var speed = 15.0" in diff_str or "+var speed = 15.0" in diff_str):
			var rb_res = cs.rollback()
			if rb_res.get("success", false):
				var f_rb = FileAccess.open(test_file, FileAccess.READ)
				var c_rb = f_rb.get_as_text()
				f_rb.close()
				if "var speed = 8.0" in c_rb and not "var speed = 15.0" in c_rb:
					passed += 1
				else:
					failed += 1
					errors.append("Test 6 (Undo rollback content) failed: " + c_rb)
			else:
				failed += 1
				errors.append("Test 6 (Rollback failed): " + str(rb_res))
		else:
			failed += 1
			errors.append("Test 6 (Diff text format) failed: " + diff_str)
	else:
		failed += 1
		errors.append("Test 6 failed: " + str(res6))
		
	# Test 7: 350+ satırlık büyük dosyada yalnızca tek hedef satırın değişmesi
	var big_file = "res://temp_big_script.gd"
	var big_lines: PackedStringArray = []
	big_lines.append("extends CharacterBody3D")
	for i in range(1, 350):
		if i == 175:
			big_lines.append("var current_gravity: float = 9.8")
		else:
			big_lines.append("var var_dummy_%d: int = %d" % [i, i])
	big_lines.append("func _process(delta: float) -> void:")
	big_lines.append("\tpass")
	
	var orig_big_str = "\n".join(big_lines)
	var f_big = FileAccess.open(big_file, FileAccess.WRITE)
	f_big.store_string(orig_big_str)
	f_big.close()
	
	var res7 = AISidebarScriptTools.execute("replace_file_content", {
		"file_path": big_file,
		"target_code": "var current_gravity: float = 9.8",
		"replacement_code": "var current_gravity: float = 24.5"
	})
	
	if res7.get("success", false):
		var f_big_read = FileAccess.open(big_file, FileAccess.READ)
		var big_content_after = f_big_read.get_as_text()
		f_big_read.close()
		
		var after_lines = big_content_after.split("\n")
		var is_exact = ("var current_gravity: float = 24.5" in big_content_after) and (not "9.8" in big_content_after) and (after_lines.size() == big_lines.size()) and ("var var_dummy_1: int = 1" in big_content_after) and ("var var_dummy_340: int = 340" in big_content_after)
		if is_exact:
			passed += 1
		else:
			failed += 1
			errors.append("Test 7 (350 lines surgical precision) failed: line count=" + str(after_lines.size()) + " expected=" + str(big_lines.size()))
	else:
		failed += 1
		errors.append("Test 7 failed: " + str(res7))
		
	# Temizlik
	DirAccess.remove_absolute(test_file)
	DirAccess.remove_absolute(big_file)
	
	return {"name": "SurgicalFileEditingTests", "passed": passed, "failed": failed, "errors": errors}
