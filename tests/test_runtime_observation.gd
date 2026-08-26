@tool
extends RefCounted

const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Initial Observation State
	var obs = AISidebarRuntimeObservation.new()
	if obs.status == AISidebarRuntimeObservation.RuntimeStatus.STOPPED and not obs.has_errors():
		passed += 1
	else:
		failed += 1
		errors.append("Başlangıç gözlem durumu hatalı.")
		
	# Test 2: Error and Stack Trace Ingestion
	obs.add_error("Invalid operands 'Nil' and 'float' in operator '+'", "res://scripts/player.gd", 42, "_physics_process", "TYPE_ERROR")
	obs.add_stack_frame("res://scripts/player.gd", 42, "_physics_process")
	obs.add_stack_frame("res://scenes/main.gd", 10, "_process")
	
	if obs.has_errors() and obs.status == AISidebarRuntimeObservation.RuntimeStatus.ERROR_DETECTED:
		passed += 1
	else:
		failed += 1
		errors.append("Hata ekleme sonrası durum güncellenmedi.")
		
	# Test 3: Diagnostic Prompt Formatting
	var prompt = obs.format_diagnostic_prompt()
	if "res://scripts/player.gd:42" in prompt and "_physics_process()" in prompt:
		passed += 1
	else:
		failed += 1
		errors.append("Teşhis promptu beklenen kaynak satırını içermiyor: " + prompt)
		
	return {"name": "RuntimeObservationTests", "passed": passed, "failed": failed, "errors": errors}
