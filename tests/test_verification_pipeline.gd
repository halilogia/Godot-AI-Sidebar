@tool
extends RefCounted

const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Valid script verification (via verify_script)
	var valid_script = "res://addons/godot_sidebar_ai/plugin.gd"
	var v_res = AISidebarVerificationPipeline.verify_script(valid_script)
	if v_res.get("success", false) and v_res.get("status") == AISidebarVerificationPipeline.VerificationStatus.PASSED:
		passed += 1
	else:
		failed += 1
		errors.append("Test 1 Başarısız: Geçerli script doğrulanamadı: " + str(v_res))
		
	# Test 2: Nonexistent script verification
	var invalid_script = "res://scripts/nonexistent_dummy.gd"
	var inv_res = AISidebarVerificationPipeline.verify_script(invalid_script)
	if not inv_res.get("success", false) and inv_res.get("status") == AISidebarVerificationPipeline.VerificationStatus.FAILED:
		passed += 1
	else:
		failed += 1
		errors.append("Test 2 Başarısız: Olmayan script hatası yakalanamadı: " + str(inv_res))
		
	# Test 3: validate_source dispatcher ile .gd doğrulama
	var gd_good = "extends Node\nfunc _ready():\n\tpass\n"
	var gd_res = AISidebarVerificationPipeline.validate_source(gd_good, "res://test_node.gd")
	if gd_res.get("success", false) and gd_res.get("status") == AISidebarVerificationPipeline.VerificationStatus.PASSED:
		passed += 1
	else:
		failed += 1
		errors.append("Test 3 Başarısız: validate_source .gd dosyasını doğrulayamadı: " + str(gd_res))
		
	# Test 4: validate_source dispatcher ile .tscn doğrulama (hatalı tscn yakalama)
	var bad_tscn = "[gd_scene load_steps=2 format=3]\n[node name=\"Root\" type=\"Node\"]\n[ext_resource type=\"Script\" path=\"res://dummy.gd\" id=\"1\"]\n"
	var tscn_res = AISidebarVerificationPipeline.validate_source(bad_tscn, "res://test_scene.tscn")
	if not tscn_res.get("success", false) and tscn_res.get("status") == AISidebarVerificationPipeline.VerificationStatus.FAILED:
		var err = tscn_res.get("error", {})
		if err.has("code") and err.has("message") and err.has("line"):
			passed += 1
		else:
			failed += 1
			errors.append("Test 4 Başarısız: Hata nesnesi standart alanları (code, message, line) içermiyor: " + str(tscn_res))
	else:
		failed += 1
		errors.append("Test 4 Başarısız: validate_source hatalı tscn'i yakalayamadı: " + str(tscn_res))
		
	# Test 5: Tanımsız dosya formatında varsayılan pass davranışı
	var txt_res = AISidebarVerificationPipeline.validate_source("hello world", "res://notes.txt")
	if txt_res.get("success", false) and txt_res.get("status") == AISidebarVerificationPipeline.VerificationStatus.PASSED:
		passed += 1
	else:
		failed += 1
		errors.append("Test 5 Başarısız: Tanımsız uzantı için varsayılan pass davranışı çalışmadı: " + str(txt_res))
		
	# Test 6: register_validator ile dinamik validator ekleme ve suggestion denetimi
	var custom_tracker = [false]
	var custom_validator = func(src: String, p: String, _batch: Dictionary) -> Dictionary:
		custom_tracker[0] = true
		if "INVALID" in src:
			return AISidebarVerificationPipeline.fail_result("CUSTOM_ERR", "Özel hata", p, 10, "Lütfen INVALID kelimesini kaldırın.")
		return AISidebarVerificationPipeline.pass_result("Özel format geçerli.")
		
	AISidebarVerificationPipeline.register_validator("customext", custom_validator)
	
	var custom_pass_res = AISidebarVerificationPipeline.validate_source("VALID DATA", "res://data.customext")
	var custom_fail_res = AISidebarVerificationPipeline.validate_source("INVALID DATA", "res://data.customext")
	
	if custom_tracker[0] and custom_pass_res.get("success", false) and not custom_fail_res.get("success", false):
		var err = custom_fail_res.get("error", {})
		if err.get("suggestion") == "Lütfen INVALID kelimesini kaldırın." and err.get("line") == 10:
			passed += 1
		else:
			failed += 1
			errors.append("Test 6 Başarısız: Custom validator suggestion veya line alanı hatalı: " + str(custom_fail_res))
	else:
		failed += 1
		errors.append("Test 6 Başarısız: Custom validator çağrılamadı: " + str(custom_fail_res))
		
	AISidebarVerificationPipeline.unregister_validator("customext")
	
	# Test 7: Engine-level verifier extension point denetimi
	var engine_tracker = [false]
	var engine_hook = func(src: String, p: String, _batch: Dictionary) -> Dictionary:
		engine_tracker[0] = true
		if "FAIL_ENGINE" in src:
			return AISidebarVerificationPipeline.fail_result("ENGINE_ERR", "Engine-level hata yakalandı", p, -1, "Engine ayarını düzeltin.")
		return AISidebarVerificationPipeline.pass_result("Engine-level onaylandı.")
		
	AISidebarVerificationPipeline.register_engine_verifier(engine_hook)
	
	var eng_pass = AISidebarVerificationPipeline.validate_source("extends Node\n", "res://temp_ok.gd")
	var eng_fail = AISidebarVerificationPipeline.validate_source("extends Node\n# FAIL_ENGINE\n", "res://temp_fail.gd")
	
	if engine_tracker[0] and eng_pass.get("success", false) and not eng_fail.get("success", false):
		passed += 1
	else:
		failed += 1
		errors.append("Test 7 Başarısız: Engine verifier kancası düzgün çalışmadı: eng_fail=" + str(eng_fail))
		
	AISidebarVerificationPipeline.clear_engine_verifiers()
		
	return {"name": "VerificationPipelineTests", "passed": passed, "failed": failed, "errors": errors}
