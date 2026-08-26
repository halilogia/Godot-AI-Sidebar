@tool
extends RefCounted

const AISidebarRuntimeObservation = preload("res://addons/godot_sidebar_ai/core/types/runtime_observation.gd")
const AISidebarSourceMapper = preload("res://addons/godot_sidebar_ai/core/runtime/source_mapper.gd")
const AISidebarRuntimeDebugger = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_debugger.gd")

static func evaluate_runtime_test(obs: AISidebarRuntimeObservation, expected_runtime_error: bool) -> Dictionary:
	if expected_runtime_error:
		if obs.has_errors() and obs.status == AISidebarRuntimeObservation.RuntimeStatus.ERROR_DETECTED:
			return {"success": true, "verdict": "PASS", "message": "Beklenen çalışma zamanı hatası başarıyla yakalandı ve kaynak satırına eşlendi."}
		else:
			return {"success": false, "verdict": "FAIL", "message": "Test çalışma zamanı hatası bekliyordu fakat hata gözlemlenemedi (" + obs.get_observation_verdict() + ")."}
	else:
		if obs.is_verified_clean():
			return {"success": true, "verdict": "PASS", "message": "Çalışma zamanı temiz ve hatasız doğrulandı."}
		elif obs.is_inconclusive():
			return {"success": false, "verdict": "INCONCLUSIVE", "message": "Gözlem penceresinde kesin temizlik kanıtlanamadı (INCONCLUSIVE)."}
		else:
			return {"success": false, "verdict": "FAIL", "message": "Beklenmeyen çalışma zamanı hatası tespit edildi: " + str(obs.errors)}

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Epistemic State Ayrımı (RUNNING + errors=[] != VERIFIED_CLEAN)
	var starting_obs = AISidebarRuntimeObservation.new()
	starting_obs.status = AISidebarRuntimeObservation.RuntimeStatus.STARTING
	starting_obs.elapsed_msec = 100
	starting_obs.is_process_alive = true
	
	if starting_obs.is_inconclusive() and not starting_obs.is_verified_clean() and not starting_obs.has_errors():
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 (STARTING epistemic state) failed.")
		
	var no_log_obs = AISidebarRuntimeObservation.new()
	no_log_obs.status = AISidebarRuntimeObservation.RuntimeStatus.NO_NEW_LOG_DATA
	no_log_obs.is_process_alive = true
	no_log_obs.new_log_bytes = 0
	
	if no_log_obs.is_inconclusive() and not no_log_obs.is_verified_clean():
		passed += 1
	else:
		failed += 1
		errors.append("Test 1b (NO_NEW_LOG_DATA is inconclusive) failed.")
		
	# Test 2: VERIFIED_CLEAN ancak checkpoint süresi ve sıfır hata ile verilmeli
	var clean_obs = AISidebarRuntimeObservation.new()
	clean_obs.status = AISidebarRuntimeObservation.RuntimeStatus.VERIFIED_CLEAN
	clean_obs.elapsed_msec = 2000
	clean_obs.is_process_alive = true
	
	if clean_obs.is_verified_clean() and not clean_obs.is_inconclusive() and not clean_obs.has_errors():
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 (VERIFIED_CLEAN state) failed.")
		
	# Test 3: Multi-Line Godot SCRIPT ERROR ve Backtrace ayrıştırma
	var sample_godot_log = """
Godot Engine v4.7.2.stable.official.ed1daf0bf
SCRIPT ERROR: Invalid call. Nonexistent function 'trigger_null_crash' in base 'Nil'.
   at: _ready (res://RuntimeErrorRealTest.gd:5)
   GDScript backtrace (most recent call first):
       [0] _ready (res://RuntimeErrorRealTest.gd:5)
       [1] _init (res://main.gd:12)
"""
	var parsed_obs = AISidebarSourceMapper.parse_log_text(sample_godot_log)
	if parsed_obs.errors.size() == 1:
		var err = parsed_obs.errors[0]
		if err.get("file") == "res://RuntimeErrorRealTest.gd" and err.get("line") == 5 and err.get("function") == "_ready":
			passed += 1
		else:
			failed += 1
			errors.append("Test 3 (Multi-line error location mismatch): " + str(err))
	else:
		failed += 1
		errors.append("Test 3 (Multi-line error parse count != 1): " + str(parsed_obs.errors))
		
	if parsed_obs.stack_trace.size() == 2:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3b (Backtrace parse count != 2): " + str(parsed_obs.stack_trace))
		
	# Test 4: Expected Runtime Error Test Metodolojisi (expected_runtime_error = true)
	# Senaryo A: Hata bekleniyordu ve gerçek hata yakalandı -> PASS
	parsed_obs.status = AISidebarRuntimeObservation.RuntimeStatus.ERROR_DETECTED
	var eval_a = evaluate_runtime_test(parsed_obs, true)
	if eval_a["success"] and eval_a["verdict"] == "PASS":
		passed += 1
	else:
		failed += 1
		errors.append("Test 4a (expected_error=true + actual error > 0 should PASS) failed: " + str(eval_a))
		
	# Senaryo B: Hata bekleniyordu fakat observer temiz/inconclusive raporladı -> FAIL (Asla PASS vermemeli)
	var eval_b = evaluate_runtime_test(starting_obs, true)
	if not eval_b["success"] and eval_b["verdict"] == "FAIL":
		passed += 1
	else:
		failed += 1
		errors.append("Test 4b (expected_error=true + actual error == 0 should FAIL) failed: " + str(eval_b))
		
	# Senaryo C: Temiz çalışma bekleniyordu fakat henüz inconclusive -> FAIL / INCONCLUSIVE
	var eval_c = evaluate_runtime_test(starting_obs, false)
	if not eval_c["success"] and eval_c["verdict"] == "INCONCLUSIVE":
		passed += 1
	else:
		failed += 1
		errors.append("Test 4c (expected_error=false + inconclusive should not PASS) failed: " + str(eval_c))
		
	# Senaryo D: Temiz çalışma bekleniyordu ve VERIFIED_CLEAN -> PASS
	var eval_d = evaluate_runtime_test(clean_obs, false)
	if eval_d["success"] and eval_d["verdict"] == "PASS":
		passed += 1
	else:
		failed += 1
		errors.append("Test 4d (expected_error=false + verified_clean should PASS) failed: " + str(eval_d))
		
	return {"name": "RuntimeStateMachineTests", "passed": passed, "failed": failed, "errors": errors}
