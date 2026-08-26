@tool
extends RefCounted

const AISidebarDiagnosisContext = preload("res://addons/godot_sidebar_ai/core/state/diagnosis_context.gd")
const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarVisualObservation = preload("res://addons/godot_sidebar_ai/core/types/visual_observation.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var r_obs = AISidebarRuntimeObservation.new()
	r_obs.add_error("Null instance on camera", "res://scripts/camera.gd", 15)
	
	var v_obs = AISidebarVisualObservation.new(null, "Boş Viewport", 0.90)
	v_obs.add_issue("EMPTY_VIEWPORT", "Kamera sahneyi çekmiyor")
	
	var diag = AISidebarDiagnosisContext.new(r_obs, v_obs, ["Created Camera2D"])
	var full_diag = diag.format_full_diagnosis()
	
	if "Null instance on camera" in full_diag and "EMPTY_VIEWPORT" in full_diag and "Created Camera2D" in full_diag:
		passed += 1
	else:
		failed += 1
		errors.append("Birleşik teşhis raporu beklenen verileri içermiyor: " + full_diag)
		
	return {"name": "DiagnosisContextTests", "passed": passed, "failed": failed, "errors": errors}
