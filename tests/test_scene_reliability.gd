@tool
extends RefCounted

## Scene Creation Reliability: parse validation, overwrite rollback,
## active-scene retry confirmation, save consistency (DETERMINISTIK).
## NOT: Tool kontratı senkron olduğu için frame yield yoktur; editor retry
## agent turunda olur. Retry DÖNGÜ mantığı enjekte provider ile kanıtlanır.

const AISidebarSceneTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/scene_tools.gd")

class FakeSceneRoot extends RefCounted:
	var scene_file_path: String = ""
	func _init(p: String = "") -> void:
		scene_file_path = p

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

static func _read(p: String) -> String:
	var f = FileAccess.open(p, FileAccess.READ)
	if not f:
		return ""
	var s = f.get_as_text()
	f.close()
	return s

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	var p_invalid = "res://tests/temp_scene_rel_invalid.tscn"
	var p_valid = "res://tests/temp_scene_rel_valid.tscn"
	var p_second = "res://tests/temp_scene_rel_second.tscn"
	_clean([p_invalid, p_valid, p_second])

	# A) Yeni geçersiz TSCN -> dosya oluşmadan SCENE_PARSE_ERROR
	var res_a = AISidebarSceneTools.execute("create_scene", {"scene_path": p_invalid, "tscn_content": INVALID_TSCN})
	var err_a = res_a.get("error", {})
	var data_a = res_a.get("data", {})
	if not bool(res_a.get("success", true)) and err_a is Dictionary and str(err_a.get("code", "")) == "SCENE_PARSE_ERROR" and not FileAccess.file_exists(p_invalid) and data_a is Dictionary and bool(data_a.get("restored", false)):
		passed += 1
	else:
		failed += 1
		errors.append("A (new invalid TSCN cleaned) failed: " + str(res_a).left(300))

	# B) Geçerli TSCN -> parse success + gerçek reload
	var res_b = AISidebarSceneTools.execute("create_scene", {"scene_path": p_valid, "tscn_content": VALID_TSCN})
	var data_b = res_b.get("data", {})
	var reloaded = ResourceLoader.load(p_valid, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if bool(res_b.get("success", false)) and data_b is Dictionary and bool(data_b.get("parse_validated", false)) and (reloaded is PackedScene):
		passed += 1
	else:
		failed += 1
		errors.append("B (valid TSCN parse success) failed: " + str(res_b).left(300))

	# C) Mevcut geçerli TSCN üzerine geçersiz içerik -> SCENE_PARSE_ERROR + eski içerik birebir
	var original_c = _read(p_valid)
	var res_c = AISidebarSceneTools.execute("create_scene", {"scene_path": p_valid, "tscn_content": INVALID_TSCN})
	var err_c = res_c.get("error", {})
	var data_c = res_c.get("data", {})
	var after_c = _read(p_valid)
	var reload_c = ResourceLoader.load(p_valid, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if not bool(res_c.get("success", true)) and err_c is Dictionary and str(err_c.get("code", "")) == "SCENE_PARSE_ERROR" and data_c is Dictionary and bool(data_c.get("existed_before", false)) and bool(data_c.get("restore_verified", false)) and after_c == original_c and (reload_c is PackedScene):
		passed += 1
	else:
		failed += 1
		errors.append("C (overwrite rollback) failed: restored=" + str(data_c.get("restored", "?") if data_c is Dictionary else "?") + " same=" + str(after_c == original_c))

	# D) Retry döngüsü: null -> yanlış -> doğru provider ile eşleşmede success
	var want_d = "res://want.tscn"
	var seq_d: Array = [null, FakeSceneRoot.new("res://wrong.tscn"), FakeSceneRoot.new(want_d)]
	var calls_d = [0]
	var provider_d = func():
		var i = mini(calls_d[0], seq_d.size() - 1)
		calls_d[0] += 1
		return seq_d[i]
	var res_d = AISidebarSceneTools.confirm_active_scene(want_d, 5, provider_d)
	var data_d = res_d.get("data", {})
	if bool(res_d.get("success", false)) and data_d is Dictionary and str(data_d.get("active_scene_path", "")) == want_d and calls_d[0] == 3:
		passed += 1
	else:
		failed += 1
		errors.append("D (retry-until-match) failed: calls=%d res=%s" % [calls_d[0], str(res_d).left(200)])

	# E) Sürekli eşleşmeme -> sınırlı deneme + ACTIVE_SCENE_NOT_CONFIRMED + gerçek path
	var bad_e = FakeSceneRoot.new("res://other.tscn")
	var calls_e = [0]
	var provider_e = func():
		calls_e[0] += 1
		return bad_e
	var res_e = AISidebarSceneTools.confirm_active_scene("res://want.tscn", 2, provider_e)
	var err_e = res_e.get("error", {})
	var data_e = res_e.get("data", {})
	var res_e2 = AISidebarSceneTools.execute("create_scene", {"scene_path": p_second, "tscn_content": VALID_TSCN})
	var data_e2 = res_e2.get("data", {})
	if not bool(res_e.get("success", true)) and err_e is Dictionary and str(err_e.get("code", "")) == "ACTIVE_SCENE_NOT_CONFIRMED" and calls_e[0] == 2 and data_e is Dictionary and str(data_e.get("active_scene_path", "")) == "res://other.tscn" and bool(res_e2.get("success", false)) and str(data_e2.get("scene_path", "")) == p_second:
		passed += 1
	else:
		failed += 1
		errors.append("E (bounded mismatch + no stale path) failed.")

	# F) save_scene mevcut davranış korunuyor (headless: NO_ACTIVE_SCENE)
	var res_f = AISidebarSceneTools.execute("save_scene", {})
	var err_f = res_f.get("error", {})
	if not bool(res_f.get("success", true)) and err_f is Dictionary and str(err_f.get("code", "")) == "NO_ACTIVE_SCENE":
		passed += 1
	else:
		failed += 1
		errors.append("F (save_scene intact) failed: " + str(res_f).left(200))

	# G) (bulgu #23) Node olmayan kök tipi -> script hatası değil INVALID_CLASS, dosya yok
	var p_g = "res://tests/temp_scene_rel_g.tscn"
	var g_bad: Array = []
	for rt in ["Resource", "Object", "Image"]:
		var res_g = AISidebarSceneTools.execute("create_scene", {"scene_path": p_g, "root_type": rt})
		var err_g = res_g.get("error", {})
		if bool(res_g.get("success", true)) or not (err_g is Dictionary) or str(err_g.get("code", "")) != "INVALID_CLASS" or FileAccess.file_exists(p_g):
			g_bad.append(rt + " -> " + str(res_g).left(120))
	if g_bad.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("G (non-Node root_type) failed: " + str(g_bad))

	_clean([p_invalid, p_valid, p_second, p_g])
	return {"name": "SceneReliabilityTests", "passed": passed, "failed": failed, "errors": errors}
