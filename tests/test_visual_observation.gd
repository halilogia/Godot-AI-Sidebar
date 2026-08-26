@tool
extends RefCounted

const AISidebarVisualObservation = preload("res://addons/godot_sidebar_ai/core/types/visual_observation.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: High Confidence Observation
	var obs_high = AISidebarVisualObservation.new(null, "Oyuncu sahnede görünüyor.", 0.95)
	if obs_high.is_confident() and not obs_high.has_issues():
		passed += 1
	else:
		failed += 1
		errors.append("Yüksek güvenilirlik tespiti hatalı.")
		
	# Test 2: Low Confidence Detection (< 0.65)
	var obs_low = AISidebarVisualObservation.new(null, "Görüntü bulanık.", 0.40)
	if not obs_low.is_confident():
		passed += 1
	else:
		failed += 1
		errors.append("Düşük güvenilirlik eşiği çalışmadı.")
		
	# Test 3: Visual Issue Ingestion & Diagnostic Prompt
	obs_high.add_issue("CAMERA_OUT_OF_BOUNDS", "Oyuncu kameranın görüş alanının dışında kalmış", "Player", "ERROR")
	if obs_high.has_issues():
		var prompt = obs_high.format_diagnostic_prompt()
		if "CAMERA_OUT_OF_BOUNDS" in prompt and "Player" in prompt:
			passed += 1
		else:
			failed += 1
			errors.append("Görsel teşhis promptu beklenen bilgileri içermiyor: " + prompt)
	else:
		failed += 1
		errors.append("Görsel sorun eklenemedi.")
		
	return {"name": "VisualObservationTests", "passed": passed, "failed": failed, "errors": errors}
