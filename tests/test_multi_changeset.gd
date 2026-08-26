@tool
extends RefCounted

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var file1 = "res://tests/integration_project/scripts/test_cs1.gd"
	var file2 = "res://tests/integration_project/scripts/test_cs2.gd"
	
	# Test 1: Multi-item ChangeSet creation and summary
	var cs = AISidebarChangeSet.new(file1, AISidebarChangeSet.ChangeType.CREATE_FILE, "extends Node\nvar a = 1", "", "Ana script")
	cs.add_sub_change(file2, AISidebarChangeSet.ChangeType.CREATE_FILE, "extends Node\nvar b = 2", "", "Yardımcı script")
	
	var summary = cs.get_summary()
	if "Değişiklik Sayısı: 2" in summary and "test_cs1.gd" in summary and "test_cs2.gd" in summary:
		passed += 1
	else:
		failed += 1
		errors.append("Multi-item ChangeSet özeti hatalı: " + summary)
		
	# Test 2: Apply both files
	var app_res = cs.apply()
	if app_res.get("success", false) and FileAccess.file_exists(file1) and FileAccess.file_exists(file2):
		passed += 1
	else:
		failed += 1
		errors.append("Multi-item ChangeSet apply başarısız: " + str(app_res))
		
	# Test 3: Cleanup / Delete test files
	if FileAccess.file_exists(file1):
		DirAccess.remove_absolute(file1)
	if FileAccess.file_exists(file2):
		DirAccess.remove_absolute(file2)
		
	if not FileAccess.file_exists(file1) and not FileAccess.file_exists(file2):
		passed += 1
	else:
		failed += 1
		errors.append("Test dosyaları temizlenemedi.")
		
	return {"name": "MultiChangeSetTests", "passed": passed, "failed": failed, "errors": errors}
