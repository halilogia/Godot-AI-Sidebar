@tool
extends RefCounted

## validate_project: bozuk betiğin hataları dosya / satır / mesajla, eksik sahne bağımlılığı dosyasıyla
## döner; temiz betik hata üretmez; araç proje dışı yolu reddeder.

const AISidebarProjectValidator = preload("res://addons/godot_sidebar_ai/core/verification/project_validator.gd")
const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")

const DIR := "res://tests/tmp_validate_project"

static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	DirAccess.make_dir_recursive_absolute(DIR)
	_write(DIR + "/ok.gd", "extends Node\n\nfunc _ready() -> void:\n\tprint(1)\n")
	_write(DIR + "/broken.gd", "extends Node\n\nfunc _ready() -> void:\n\tvar x: int = \"a\"\n")
	_write(DIR + "/scene.tscn", "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://tests/tmp_validate_project/missing.gd\" id=\"1\"]\n\n[node name=\"Root\" type=\"Node\"]\nscript = ExtResource(\"1\")\n")

	var report := AISidebarProjectValidator.run(DIR)
	var errs: Array = report.get("errors", [])
	var broken_hit := false
	var dep_hit := false
	var ok_hit := false
	for e: Dictionary in errs:
		var file := str(e.get("file", ""))
		if file.ends_with("broken.gd") and int(e.get("line", 0)) == 4 and not str(e.get("message", "")).is_empty():
			broken_hit = true
		if file.ends_with("scene.tscn") and str(e.get("message", "")).contains("missing.gd"):
			dep_hit = true
		if file.ends_with("ok.gd"):
			ok_hit = true
	if broken_hit and dep_hit and not ok_hit and int(report.get("scripts_checked", 0)) == 2 and report.has("duration_ms") and not str(report.get("engine", "")).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T1 validator: " + JSON.stringify(report).left(600))

	var tool_res := AISidebarScriptTools.execute("validate_project", {"path": DIR})
	var bad_path := AISidebarScriptTools.execute("validate_project", {"path": "C:/Windows"})
	var tool_err: Dictionary = tool_res.get("error", {}) if tool_res.get("error") is Dictionary else {}
	var bad_err: Dictionary = bad_path.get("error", {}) if bad_path.get("error") is Dictionary else {}
	if tool_res.get("success") == false and str(tool_err.get("code", "")) == "PROJECT_VALIDATION_FAILED" and str(bad_err.get("code", "")) == "INVALID_ARGUMENT":
		passed += 1
	else:
		failed += 1
		errors.append("T2 tool: %s / %s" % [JSON.stringify(tool_res).left(300), JSON.stringify(bad_path).left(200)])

	for f: String in ["ok.gd", "broken.gd", "scene.tscn"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	return {"name": "ProjectValidatorTests", "passed": passed, "failed": failed, "errors": errors}
