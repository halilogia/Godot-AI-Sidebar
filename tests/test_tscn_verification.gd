@tool
extends RefCounted

const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")
const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var valid_tscn_path = "res://tests/temp_valid_scene.tscn"
	var invalid_tscn_path = "res://tests/temp_invalid_scene.tscn"
	var dummy_script_path = "res://tests/temp_tscn_dummy.gd"
	
	# Temizlik
	for p in [valid_tscn_path, invalid_tscn_path, dummy_script_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
			
	# Önce geçerli bir dummy script oluşturalım
	var f_dummy = FileAccess.open(dummy_script_path, FileAccess.WRITE)
	if f_dummy:
		f_dummy.store_string("extends Node\n")
		f_dummy.close()
		
	# -------------------------------------------------------------
	# Test 1: Geçerli TSCN -> PASS
	# -------------------------------------------------------------
	var valid_tscn_content = """[gd_scene load_steps=3 format=3 uid="uid://testvalid001"]
[ext_resource type="Script" path="%s" id="1_test"]
[sub_resource type="BoxShape3D" id="sub_1"]
size = Vector3(1, 1, 1)
[node name="TestRoot" type="Node3D"]
[node name="Collision" type="CollisionShape3D" parent="."]
shape = SubResource("sub_1")
script = ExtResource("1_test")
""" % [dummy_script_path]

	var res_1 = AISidebarVerificationPipeline.validate_tscn_source(valid_tscn_content, valid_tscn_path)
	if res_1.get("success", false) and res_1.get("status") == AISidebarVerificationPipeline.VerificationStatus.PASSED:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 Başarısız: Geçerli TSCN onaylanmadı: " + str(res_1))

	# -------------------------------------------------------------
	# Test 2: ext_resource yanlış sırada (sub_resource sonrası) -> FAIL
	# -------------------------------------------------------------
	var displaced_ext_content = """[gd_scene load_steps=3 format=3 uid="uid://testdisplaced002"]
[sub_resource type="BoxShape3D" id="sub_1"]
size = Vector3(1, 1, 1)
[ext_resource type="Script" path="%s" id="1_test"]
[node name="TestRoot" type="Node3D"]
""" % [dummy_script_path]

	var res_2 = AISidebarVerificationPipeline.validate_tscn_source(displaced_ext_content, invalid_tscn_path)
	if not res_2.get("success", false) and res_2.get("error", {}).get("code") == "TSCN_DISPLACED_EXT_RESOURCE":
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 Başarısız: Yanlış sıradaki ext_resource yakalanamadı: " + str(res_2))

	# -------------------------------------------------------------
	# Test 3: Duplicate resource ID (id="1_dup" iki kez) -> FAIL
	# -------------------------------------------------------------
	var duplicate_id_content = """[gd_scene load_steps=3 format=3 uid="uid://testdup003"]
[ext_resource type="Script" path="%s" id="1_dup"]
[ext_resource type="Script" path="%s" id="1_dup"]
[node name="TestRoot" type="Node3D"]
""" % [dummy_script_path, dummy_script_path]

	var res_3 = AISidebarVerificationPipeline.validate_tscn_source(duplicate_id_content, invalid_tscn_path)
	if not res_3.get("success", false) and res_3.get("error", {}).get("code") == "TSCN_DUPLICATE_RESOURCE_ID":
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 Başarısız: Mükerrer resource ID yakalanamadı: " + str(res_3))

	# -------------------------------------------------------------
	# Test 4: Bozuk/tanımsız resource referansı (ExtResource("999_none")) -> FAIL
	# -------------------------------------------------------------
	var broken_ref_content = """[gd_scene load_steps=2 format=3 uid="uid://testbroken004"]
[ext_resource type="Script" path="%s" id="1_test"]
[node name="TestRoot" type="Node3D"]
script = ExtResource("999_none")
""" % [dummy_script_path]

	var res_4 = AISidebarVerificationPipeline.validate_tscn_source(broken_ref_content, invalid_tscn_path)
	if not res_4.get("success", false) and res_4.get("error", {}).get("code") == "TSCN_UNDEFINED_RESOURCE_REFERENCE":
		passed += 1
	else:
		failed += 1
		errors.append("Test 4 Başarısız: Tanımsız resource referansı yakalanamadı: " + str(res_4))

	# -------------------------------------------------------------
	# Test 5: Doğrulama FAIL olduğunda dosya disk üzerinde ASLA değişmemeli
	# -------------------------------------------------------------
	var disk_test_path = "res://tests/temp_disk_integrity.tscn"
	var initial_content = """[gd_scene load_steps=2 format=3]
[node name="InitialRoot" type="Node3D"]
"""
	# Başlangıç dosyasını diske yaz
	var f_init = FileAccess.open(disk_test_path, FileAccess.WRITE)
	if f_init:
		f_init.store_string(initial_content)
		f_init.close()
		
	# Hatalı (displaced ext_resource) içerikle üzerine yazmayı dene
	var bad_overwrite = """[gd_scene load_steps=3 format=3]
[sub_resource type="BoxShape3D" id="sub_x"]
size = Vector3(1, 1, 1)
[ext_resource type="Script" path="%s" id="bad_x"]
[node name="BadRoot" type="Node3D"]
""" % [dummy_script_path]

	var tool_res = AISidebarScriptTools.execute("create_or_update_script", {
		"file_path": disk_test_path,
		"content": bad_overwrite
	})
	
	var f_check = FileAccess.open(disk_test_path, FileAccess.READ)
	var on_disk_now = f_check.get_as_text() if f_check else ""
	if f_check: f_check.close()
	
	if not tool_res.get("success", false) and on_disk_now == initial_content:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 Başarısız: Hatalı içerik diske yazıldı veya hata fırlatılmadı: tool_res=" + str(tool_res))

	# -------------------------------------------------------------
	# Test 6: Düzeltildikten sonra geçerli TSCN -> PASS ve diske yazılmalı
	# -------------------------------------------------------------
	var fixed_content = """[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="%s" id="good_x"]
[sub_resource type="BoxShape3D" id="sub_x"]
size = Vector3(1, 1, 1)
[node name="GoodRoot" type="Node3D"]
script = ExtResource("good_x")
""" % [dummy_script_path]

	var tool_res_fixed = AISidebarScriptTools.execute("create_or_update_script", {
		"file_path": disk_test_path,
		"content": fixed_content
	})
	
	var f_check2 = FileAccess.open(disk_test_path, FileAccess.READ)
	var on_disk_fixed = f_check2.get_as_text() if f_check2 else ""
	if f_check2: f_check2.close()
	
	if tool_res_fixed.get("success", false) and on_disk_fixed == fixed_content:
		passed += 1
	else:
		failed += 1
		errors.append("Test 6 Başarısız: Düzeltilen geçerli TSCN diske yazılamadı: " + str(tool_res_fixed))

	# Temizlik
	for p in [valid_tscn_path, invalid_tscn_path, dummy_script_path, disk_test_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

	return {"name": "TSCNVerificationTests", "passed": passed, "failed": failed, "errors": errors}
