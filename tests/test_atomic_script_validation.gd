@tool
extends RefCounted

const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var valid_path = "res://tests/temp_valid_script.gd"
	var invalid_path = "res://tests/temp_invalid_script.gd"
	
	# Temizlik
	if FileAccess.file_exists(valid_path):
		DirAccess.remove_absolute(valid_path)
	if FileAccess.file_exists(invalid_path):
		DirAccess.remove_absolute(invalid_path)
		
	# Test 1: Geçerli script yazımı
	var valid_code = "extends Node\nfunc _ready() -> void:\n\tprint('Hello')\n"
	var res1 = AISidebarScriptTools.execute("create_or_update_script", {"file_path": valid_path, "content": valid_code})
	if res1.get("success", false) and FileAccess.file_exists(valid_path):
		passed += 1
	else:
		failed += 1
		errors.append("Geçerli script yazılamadı: " + str(res1))
		
	# Test 2: Geçersiz sözdizimi olan script diske YAZILMAMALI
	var invalid_code = "extends Node\nfunc _ready( -> void:\n\tprint('Missing parenthesis')" # Syntax error!
	var res2 = AISidebarScriptTools.execute("create_or_update_script", {"file_path": invalid_path, "content": invalid_code})
	if not res2.get("success", false) and not FileAccess.file_exists(invalid_path):
		passed += 1
	else:
		failed += 1
		errors.append("Geçersiz script hatalı şekilde diske yazıldı!")
		
	# Test 3: Mevcut geçerli dosyanın üzerine geçersiz kod yazılmaya çalışıldığında orijinal dosya KORUNMALI
	var res3 = AISidebarScriptTools.execute("create_or_update_script", {"file_path": valid_path, "content": invalid_code})
	var f = FileAccess.open(valid_path, FileAccess.READ)
	var disk_content = f.get_as_text() if f else ""
	if f: f.close()
	
	if not res3.get("success", false) and disk_content == valid_code:
		passed += 1
	else:
		failed += 1
		errors.append("Mevcut geçerli dosya geçersiz kodla bozuldu!")
		
	# Test 4: Hata objesi yapısal alanları taşıyor mu?
	var err_obj = res3.get("error", {})
	if err_obj.get("code") == "SCRIPT_SYNTAX_ERROR" and not str(err_obj.get("message", "")).is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("Hata nesnesi beklenen yapısal alanları taşımıyor: " + str(res3))
		
	# A validation failure must reach MCP and transcript consumers as a failure.
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	invalid_file.store_string("extends RefCounted\nvar value: MissingReportType\n")
	invalid_file.close()
	var validation := AISidebarScriptTools.execute("validate_script", {"file_path": invalid_path})
	if not validation.get("success", true) and validation.get("data", {}).get("error", {}).get("file_path") == invalid_path:
		passed += 1
	else:
		failed += 1
		errors.append("Validation hid an unresolved type or lost its file path: " + str(validation))
	var missing_arg := AISidebarScriptTools.execute("validate_script", {"path": valid_path})
	if not missing_arg.get("success", true) and missing_arg.get("error", {}).get("code") == "INVALID_ARGUMENT":
		passed += 1
	else:
		failed += 1
		errors.append("Validation must identify the required file_path argument")
	var own_class := AISidebarScriptTools.execute("validate_script", {"file_path": "res://addons/godot_sidebar_ai/core/types/tool_result.gd"})
	if own_class.get("success", false) and own_class.get("data", {}).get("success", false):
		passed += 1
	else:
		failed += 1
		errors.append("Validation rejected a registered class at its own path: " + str(own_class))
	for path in [valid_path, invalid_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	return {"name": "AtomicScriptValidationTests", "passed": passed, "failed": failed, "errors": errors}
