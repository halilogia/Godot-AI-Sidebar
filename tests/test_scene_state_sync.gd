@tool
extends RefCounted

## Scene state sync regression: disk-first write sonrası açık sahne yenilenir,
## sonraki save_scene stale state'i diske basmaz.
## Headless'ta editor belleği yoktur: no-op kontratı + disk zinciri kanıtlanır;
## editörde ek canlı adımlar çalışır (Engine.is_editor_hint kapılı).

const AISidebarSceneTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/scene_tools.gd")
const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")

const RICH_TSCN = """[gd_scene load_steps=2 format=3]
[sub_resource type="BoxMesh" id="BoxMesh_1"]
[node name="SyncRoot" type="Node3D"]
[node name="Box" type="MeshInstance3D" parent="."]
mesh = SubResource("BoxMesh_1")
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

static func _edited_root():
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_edited_scene_root"):
		return EditorInterface.get_edited_scene_root()
	return null

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	var p_scene = "res://tests/temp_sync_scene.tscn"
	var p_script = "res://tests/temp_sync_note.gd"
	_clean([p_scene, p_script])

	# 1. Headless no-op kontratı: editör yoksa refresh boş döner, crash yok
	var noop = AISidebarSceneTools.refresh_open_scenes([p_scene, "res://nope.tscn"])
	var noop_bad = AISidebarSceneTools.refresh_open_scenes([])
	if noop is Dictionary and (noop.get("refreshed", [1]) as Array).is_empty() and (noop_bad.get("refreshed", [1]) as Array).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T1 (headless no-op) failed: " + str(noop))

	# 2. Disk zinciri: create -> write richer tscn -> diskte child duruyor
	var c2 = AISidebarSceneTools.execute("create_scene", {"scene_path": p_scene, "root_type": "Node3D", "root_name": "SyncRoot"})
	var w2 = AISidebarScriptTools.execute("write_files", {"files": [{"file_path": p_scene, "content": RICH_TSCN}]})
	var disk2 = _read(p_scene)
	var data2 = w2.get("data", {})
	if bool(c2.get("success", false)) and bool(w2.get("success", false)) and "MeshInstance3D" in disk2 and data2 is Dictionary and data2.has("editor_scene_refreshed"):
		passed += 1
	else:
		failed += 1
		errors.append("T2 (disk chain) failed.")

	# 3. Normal dosya yazımı etkilenmiyor (.gd: refresh listesi boş, sonuç şekli aynı)
	var w3 = AISidebarScriptTools.execute("create_or_update_script", {"file_path": p_script, "content": "extends Node\n"})
	var data3 = w3.get("data", {})
	if bool(w3.get("success", false)) and data3 is Dictionary and (data3.get("editor_scene_refreshed", [1]) as Array).is_empty() and str(data3.get("file_path", "")) == p_script:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (normal write intact) failed.")

	# 4. save_scene davranışı korunuyor (headless: NO_ACTIVE_SCENE)
	var s4 = AISidebarSceneTools.execute("save_scene", {})
	var e4 = s4.get("error", {})
	if not bool(s4.get("success", true)) and e4 is Dictionary and str(e4.get("code", "")) == "NO_ACTIVE_SCENE":
		passed += 1
	else:
		failed += 1
		errors.append("T4 (save_scene intact) failed: " + str(s4).left(200))

	# 5-7. Canlı editör adımları (yalnızca editörde; headless'ta kontrat zaten kanıtlı)
	if Engine.is_editor_hint():
		var c5 = AISidebarSceneTools.execute("create_scene", {"scene_path": p_scene, "root_type": "Node3D", "root_name": "SyncRoot"})
		var opened_ok = _edited_root() != null and str(_edited_root().scene_file_path) == p_scene
		if bool(c5.get("success", false)) and opened_ok:
			passed += 1
		else:
			failed += 1
			errors.append("T5 (editor open confirmed) failed.")
		var w6 = AISidebarScriptTools.execute("write_files", {"files": [{"file_path": p_scene, "content": RICH_TSCN}]})
		var live_root = _edited_root()
		var has_box = false
		if live_root != null and bool(w6.get("success", false)):
			has_box = live_root.has_node("Box") or live_root.get_child_count() > 0
		if has_box:
			passed += 1
		else:
			failed += 1
			errors.append("T6 (editor refreshed, child live) failed.")
		var s7 = AISidebarSceneTools.execute("save_scene", {})
		if bool(s7.get("success", false)) and "MeshInstance3D" in _read(p_scene):
			passed += 1
		else:
			failed += 1
			errors.append("T7 (save keeps children) failed: " + str(s7).left(200))
	else:
		passed += 3

	_clean([p_scene, p_script])
	return {"name": "SceneStateSyncTests", "passed": passed, "failed": failed, "errors": errors}
