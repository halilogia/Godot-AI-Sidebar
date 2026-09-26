@tool
extends RefCounted

## Benchmark bulgusu: validate_script, kendi dosyasına kayıtlı `class_name`'i olan her geçerli
## script için "error 43" (Class X hides a global script class) veriyordu.

const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	# Yolsuz derlemede gerçekten çakışan (43) global sınıflı bir dosya bul.
	var path := ""
	var src := ""
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var p := str(entry.get("path", ""))
		if not p.ends_with(".gd") or not FileAccess.file_exists(p):
			continue
		var s := FileAccess.get_file_as_string(p)
		var raw := GDScript.new()
		raw.source_code = s
		if raw.reload() == ERR_PARSE_ERROR:
			path = p
			src = s
			break

	if path.is_empty():
		failed += 1
		errors.append("T1: no global class reproduces the hides-a-global-class conflict (class cache missing?)")
		return {"name": "ValidateOwnClassNameTests", "passed": passed, "failed": failed, "errors": errors}

	var own := AISidebarVerificationPipeline.validate_script_source(src, path)
	var elsewhere := AISidebarVerificationPipeline.validate_script_source(src, "res://__elsewhere__/copy.gd")
	var broken := AISidebarVerificationPipeline.validate_script_source(src + "\nfunc __broken(:\n", path)
	if own.get("success", false) and not elsewhere.get("success", true) and not broken.get("success", true):
		passed += 1
	else:
		failed += 1
		errors.append("T1 (%s) own=%s elsewhere=%s broken=%s" % [path, str(own.get("success")), str(elsewhere.get("success")), str(broken.get("success"))])

	return {"name": "ValidateOwnClassNameTests", "passed": passed, "failed": failed, "errors": errors}
