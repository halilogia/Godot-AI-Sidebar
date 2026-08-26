@tool
extends RefCounted

const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")
const AISidebarVisualObservation = preload("res://addons/godot_sidebar_ai/core/types/visual_observation.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Visual Verification PASSED
	var obs_clean = AISidebarVisualObservation.new(null, "Her şey net", 0.95)
	var res_clean = AISidebarVerificationPipeline.verify_visual_observation(obs_clean)
	if res_clean.get("status") == AISidebarVerificationPipeline.VerificationStatus.PASSED:
		passed += 1
	else:
		failed += 1
		errors.append("Temiz görsel gözlem PASSED dönmedi: " + str(res_clean))
		
	# Test 2: Visual Verification FAILED on anomaly
	var obs_anomaly = AISidebarVisualObservation.new(null, "Kamera bozuk", 0.90)
	obs_anomaly.add_issue("CAMERA_MISSING", "Hedef takip edilmiyor")
	var res_anomaly = AISidebarVerificationPipeline.verify_visual_observation(obs_anomaly)
	if res_anomaly.get("status") == AISidebarVerificationPipeline.VerificationStatus.FAILED:
		passed += 1
	else:
		failed += 1
		errors.append("Anomali içeren görsel gözlem FAILED dönmedi: " + str(res_anomaly))
		
	# Test 3: Visual Verification INCONCLUSIVE on low confidence (< 0.65)
	var obs_low = AISidebarVisualObservation.new(null, "Emin değilim", 0.40)
	var res_low = AISidebarVerificationPipeline.verify_visual_observation(obs_low)
	if res_low.get("status") == AISidebarVerificationPipeline.VerificationStatus.INCONCLUSIVE:
		passed += 1
	else:
		failed += 1
		errors.append("Düşük güvenilirlikli görsel gözlem INCONCLUSIVE dönmedi: " + str(res_low))
		
	return {"name": "ExtendedVerificationTests", "passed": passed, "failed": failed, "errors": errors}
