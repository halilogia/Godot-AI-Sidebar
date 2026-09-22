@tool
extends RefCounted

## Scene Creation Reliability: parse validation, active-scene confirmation,
## save consistency için DETERMINISTIK testler (headless: editor adımları atlanır,
## parse-yükleme Godot resource sistemiyle gerçekten yapılır).

const AISidebarSceneTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/scene_tools.gd")

const VALID_TSCN = """[gd_scene load_steps=2 format=3]
[sub_resource type="BoxMesh" id="BoxMesh_1"]
[node name="RelRoot" type="Node3D"]
[node name="Box" type="MeshInstance3D" parent="."]
mesh = SubResource("BoxMesh_1")
"""

const INVALID_TSCN = """[gd_scene load_steps=2 format=3]
[node name="RelRoot" type="Node3D"]
[node name="Box" type="MeshInstance3D" parent="."]
mesh = BoxMesh.new()
"""

static func _clean(paths: Array) -> void:
	for p in paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	var p_invalid = "res://tests/temp_scene_rel_invalid.tscn"
	var p_valid = "res://tests/temp_scene_rel_valid.tscn"
	var p_second = "res://tests/temp_scene_rel_second.tscn"
	_clean([p_invalid, p_valid, p_second])

	# A) Geçersiz TSCN -> SCENE_PARSE_ERROR, oluşturuldu raporlanmaz, dosya temizlenir
	var res_a = AISidebarSceneTools.execute("create_scene", {"scene_path": p_invalid, "tscn_content": INVALID_TSCN})
	var err_a = res_a.get("error", {})
	var code_a = str(err_a.get("code", "")) if err_a is Dictionary else ""
	if not bool(res_a.get("success", true)) and code_a == "SCENE_PARSE_ERROR" and not FileAccess.file_exists(p_invalid) and p_invalid in str(res_a.get("data", {}).get("scene_path", res_a.get("message", "")) + str(res_a)):
		passed += 1
	else:
		failed += 1
		errors.append("A (invalid TSCN -> SCENE_PARSE_ERROR) failed: " + str(res_a).left(300))

	# B) Geçerli TSCN -> create success + parse_validated, dosya gerçekten yükleniyor
	var res_b = AISidebarSceneTools.execute("create_scene", {"scene_path": p_valid, "tscn_content": VALID_TSCN})
	var data_b = res_b.get("data", {})
	var reloaded = ResourceLoader.load(p_valid, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if bool(res_b.get("success", false)) and data_b is Dictionary and bool(data_b.get("parse_validated", false)) and (reloaded is PackedScene):
		passed += 1
	else:
		failed += 1
		errors.append("B (valid TSCN create+parse) failed: " + str(res_b).left(300))

	# C) Headless'te "açıldı" iddiası yok: active_scene_confirmed=false + confirm yapısal err
	var confirm_c = AISidebarSceneTools.confirm_active_scene(p_valid)
	var cerr_c = confirm_c.get("error", {})
	if data_b is Dictionary and not bool(data_b.get("active_scene_confirmed", true)) and not bool(confirm_c.get("success", true)) and cerr_c is Dictionary and not str(cerr_c.get("code", "")).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("C (no false opened claim) failed: " + str(data_b).left(200))

	# D) Ardışık iki scene: ikinci sonuç ikinci path'i taşır (stale path yok)
	var res_d = AISidebarSceneTools.execute("create_scene", {"scene_path": p_second, "tscn_content": VALID_TSCN})
	var data_d = res_d.get("data", {})
	if bool(res_d.get("success", false)) and data_d is Dictionary and str(data_d.get("scene_path", "")) == p_second and FileAccess.file_exists(p_valid) and FileAccess.file_exists(p_second):
		passed += 1
	else:
		failed += 1
		errors.append("D (second scene path correct) failed: " + str(res_d).left(300))

	# E) save_scene mevcut davranış korunuyor (headless: NO_ACTIVE_SCENE)
	var res_e = AISidebarSceneTools.execute("save_scene", {})
	var err_e = res_e.get("error", {})
	if not bool(res_e.get("success", true)) and err_e is Dictionary and str(err_e.get("code", "")) == "NO_ACTIVE_SCENE":
		passed += 1
	else:
		failed += 1
		errors.append("E (save_scene behavior intact) failed: " + str(res_e).left(200))

	_clean([p_invalid, p_valid, p_second])
	return {"name": "SceneReliabilityTests", "passed": passed, "failed": failed, "errors": errors}
