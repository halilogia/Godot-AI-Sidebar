@tool
extends RefCounted

const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Valid script verification
	var valid_script = "res://addons/godot_sidebar_ai/plugin.gd"
	var v_res = AISidebarVerificationPipeline.verify_script(valid_script)
	if v_res.get("success", false) and v_res.get("status") == AISidebarVerificationPipeline.VerificationStatus.PASSED:
		passed += 1
	else:
		failed += 1
		errors.append("Geçerli script doğrulanamadı: " + str(v_res))
		
	# Test 2: Nonexistent script verification
	var invalid_script = "res://scripts/nonexistent_dummy.gd"
	var inv_res = AISidebarVerificationPipeline.verify_script(invalid_script)
	if not inv_res.get("success", false) and inv_res.get("status") == AISidebarVerificationPipeline.VerificationStatus.FAILED:
		passed += 1
	else:
		failed += 1
		errors.append("Olmayan script hatası yakalanamadı: " + str(inv_res))
		
	return {"name": "VerificationPipelineTests", "passed": passed, "failed": failed, "errors": errors}
