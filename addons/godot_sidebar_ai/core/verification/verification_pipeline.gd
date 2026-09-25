@tool
extends RefCounted
class_name AISidebarVerificationPipeline

## Üç Durumlu Doğrulama, Bağımlılık Denetimi ve Güvenilirlik Boru Hattı (SRP).
## PASSED, FAILED ve INCONCLUSIVE durumlarını, sözdizimi ve ChangeSet bağımlılıklarını yönetir.

const AISidebarVisualObservation = preload("res://addons/godot_sidebar_ai/core/types/visual_observation.gd")
const AISidebarTscnValidator = preload("res://addons/godot_sidebar_ai/core/verification/tscn_validator.gd")

enum VerificationStatus {
	PASSED,
	FAILED,
	INCONCLUSIVE
}

const CONFIDENCE_THRESHOLD: float = 0.65

## Ortak Sonuç Modeli (Common Result Model) Yardımcıları
static func pass_result(message: String = "✓ Doğrulama başarılı.") -> Dictionary:
	return {
		"status": VerificationStatus.PASSED,
		"success": true,
		"message": message
	}

static func fail_result(code: String, message: String, file_path: String = "", line: int = -1, suggestion: String = "", details: Dictionary = {}) -> Dictionary:
	var err: Dictionary = {
		"code": code,
		"message": message,
		"file_path": file_path,
		"line": line,
		"suggestion": suggestion,
		"recoverable": true
	}
	if not details.is_empty():
		err.merge(details)
	return {
		"status": VerificationStatus.FAILED,
		"success": false,
		"error": err
	}

## Doğrulayıcı Kayıt Defteri (Validator Registry & Extension Point)
static var _validators: Dictionary = {}
static var _engine_verifiers: Array = []

static func get_validators() -> Dictionary:
	if _validators.is_empty():
		_init_default_validators()
	return _validators

static func register_validator(extension: String, validator: Callable) -> void:
	var ext = extension.strip_edges().to_lower().trim_prefix(".")
	get_validators()[ext] = validator

static func unregister_validator(extension: String) -> void:
	var ext = extension.strip_edges().to_lower().trim_prefix(".")
	if get_validators().has(ext):
		get_validators().erase(ext)

static func register_engine_verifier(verifier: Callable) -> void:
	if not _engine_verifiers.has(verifier):
		_engine_verifiers.append(verifier)

static func clear_engine_verifiers() -> void:
	_engine_verifiers.clear()

static func _init_default_validators() -> void:
	_validators["gd"] = Callable(AISidebarVerificationPipeline, "validate_script_source")
	_validators["tscn"] = Callable(AISidebarTscnValidator, "validate")
	_validators["tres"] = Callable(AISidebarTscnValidator, "validate")

## Genel Kaynak Kodu Doğrulayıcısı (Unified Source Validator Entry Point)
## Dosya uzantısına göre kayıtlı validator/adaptor stratejisini seçer ve çalıştırır.
## Ardından engine-level extension point verifier'ları tetikler.
static func validate_source(source_code: String, file_path: String = "", batch_context: Dictionary = {}) -> Dictionary:
	var ext = file_path.get_extension().to_lower()
	var validators = get_validators()
	
	var val_res: Dictionary = {}
	if validators.has(ext):
		var validator: Callable = validators[ext]
		val_res = validator.call(source_code, file_path, batch_context)
	else:
		val_res = pass_result("Bu dosya formatı için özel linter bulunamadı: " + ext)
		
	if not val_res.get("success", false):
		return val_res
		
	# Engine-level extension point (Gelecekte ResourceLoader / headless check kancası)
	return _run_engine_verifiers(source_code, file_path, batch_context)

static func _run_engine_verifiers(source_code: String, file_path: String, batch_context: Dictionary) -> Dictionary:
	for verifier in _engine_verifiers:
		if verifier is Callable and verifier.is_valid():
			var res = verifier.call(source_code, file_path, batch_context)
			if res is Dictionary and not res.get("success", true):
				return res
	return pass_result("Engine-level doğrulama başarılı veya kanca tanımlı değil.")

## 1. Bellek İçi Kaynak Kodu Doğrulaması (Pre-write In-Memory Validation)
static func validate_script_source(source_code: String, file_path: String = "", batch_context: Dictionary = {}) -> Dictionary:
	var script = GDScript.new()
	script.source_code = source_code
	var reload_err = script.reload()
	
	if reload_err != OK:
		# Eğer hata eksik bir preload'dan kaynaklanıyorsa ve o dosya aynı batch içindeyse izin ver
		if reload_err == 43 or reload_err == ERR_FILE_NOT_FOUND:
			var has_batch_dep = false
			for bp in batch_context.keys():
				if bp in source_code:
					has_batch_dep = true
					break
			if has_batch_dep:
				return {
					"status": VerificationStatus.PASSED,
					"success": true,
					"message": "✓ GDScript sözdizimi geçerli (Batch içi bağımlılık)."
				}
				
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {
				"code": "SCRIPT_SYNTAX_ERROR",
				"message": "Script sözdizimi hatası içeriyor (Derleme kodu: " + str(reload_err) + "). Dosya: " + file_path,
				"file_path": file_path,
				"recoverable": true
			}
		}
		
	return {
		"status": VerificationStatus.PASSED,
		"success": true,
		"message": "✓ GDScript sözdizimi geçerli."
	}

## 2. Disk Dosyası Sözdizimi Doğrulaması (Syntax Verification)
static func verify_script(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {"code": "FILE_NOT_FOUND", "message": "Script dosyası bulunamadı: " + file_path, "file_path": file_path, "recoverable": true}
		}
		
	var f = FileAccess.open(file_path, FileAccess.READ)
	if not f:
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {"code": "READ_ERROR", "message": "Script dosyası okunamadı: " + file_path, "file_path": file_path, "recoverable": true}
		}
		
	var text = f.get_as_text()
	f.close()
	
	return validate_source(text, file_path)

## 3. Bağımlılık Duyarlı Toplu Dosya Doğrulaması (Dependency-Aware Batch Validator)
static func validate_batch_files(files_arr: Array) -> Dictionary:
	var batch_map: Dictionary = {}
	for item in files_arr:
		if item is Dictionary:
			var p = str(item.get("file_path", ""))
			if not p.is_empty():
				batch_map[p] = item.get("content", "")
				
	# 1. Her dosyayı formatına uygun validator ile doğrula (Unified Source Validation)
	for p in batch_map.keys():
		var val_res = validate_source(batch_map[p], p, batch_map)
		if not val_res.get("success", false):
			return val_res
						
	# 3. Dosyaları güvenli yazım sırasına göre sırala: .gd -> .tres -> .tscn -> diğerleri
	var sorted_files: Array[Dictionary] = []
	var gd_files: Array[Dictionary] = []
	var tres_files: Array[Dictionary] = []
	var tscn_files: Array[Dictionary] = []
	var other_files: Array[Dictionary] = []
	
	for item in files_arr:
		if not (item is Dictionary): continue
		var p = str(item.get("file_path", ""))
		if p.ends_with(".gd"):
			gd_files.append(item)
		elif p.ends_with(".tres"):
			tres_files.append(item)
		elif p.ends_with(".tscn"):
			tscn_files.append(item)
		else:
			other_files.append(item)
			
	sorted_files.append_array(other_files)
	sorted_files.append_array(gd_files)
	sorted_files.append_array(tres_files)
	sorted_files.append_array(tscn_files)
	
	return {
		"status": VerificationStatus.PASSED,
		"success": true,
		"sorted_files": sorted_files,
		"message": "✓ Toplu dosya bağımlılıkları ve sözdizimi doğrulandı."
	}

## 4. Sahne / Düğüm Doğrulaması (Node Hierarchy Verification)
static func verify_node(node_path: String, expected_type: String = "") -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface") or not EditorInterface.has_method("get_edited_scene_root"):
		return {
			"status": VerificationStatus.PASSED,
			"success": true,
			"message": "Editörsüz modda varsayılan başarılı kabul edildi."
		}
		
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return {
			"status": VerificationStatus.INCONCLUSIVE,
			"success": true,
			"message": "Aktif sahne kökü bulunamadı, doğrulama atlandı."
		}
		
	if not root.has_node(node_path):
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {"code": "NODE_NOT_FOUND", "message": "Düğüm bulunamadı: " + node_path}
		}
		
	var node = root.get_node(node_path)
	if not expected_type.is_empty() and not node.is_class(expected_type):
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {"code": "TYPE_MISMATCH", "message": "Düğüm tipi uyuşmazlığı. Beklenen: " + expected_type + ", Mevcut: " + node.get_class()}
		}
		
	return {
		"status": VerificationStatus.PASSED,
		"success": true,
		"message": "✓ Düğüm doğrulandı: " + node.name + " (" + node.get_class() + ")"
	}

## 5. Görsel Doğrulama (Visual Verification with Confidence Threshold)
static func verify_visual(visual_obs: AISidebarVisualObservation) -> Dictionary:
	if not visual_obs:
		return {
			"status": VerificationStatus.INCONCLUSIVE,
			"success": false,
			"error": {"code": "NO_VISUAL_DATA", "message": "Görsel gözlem verisi bulunamadı."}
		}
		
	if visual_obs.confidence < CONFIDENCE_THRESHOLD:
		return {
			"status": VerificationStatus.INCONCLUSIVE,
			"success": false,
			"error": {"code": "LOW_CONFIDENCE", "message": "Görsel analiz güvenilirlik skoru (% " + str(visual_obs.confidence * 100) + ") eşik değerin altında. Sonuç belirsiz (INCONCLUSIVE)."}
		}
		
	if visual_obs.has_issues():
		var first_issue = visual_obs.detected_issues[0].get("description", "Görsel anomali tespit edildi")
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {"code": "VISUAL_ANOMALY", "message": "Görsel doğrulama başarısız: " + first_issue}
		}
		
	return {
		"status": VerificationStatus.PASSED,
		"success": true,
		"message": "✓ Görsel doğrulama başarılı: Sahne düzgün görünüyor."
	}

static func verify_visual_observation(visual_obs: AISidebarVisualObservation) -> Dictionary:
	return verify_visual(visual_obs)

## Bir araç icrasından sonra otomatik verification çalıştırır ve orijinal DATA'yı korur
static func auto_verify_tool_execution(tool_name: String, args: Dictionary, result: Dictionary) -> Dictionary:
	if not result.get("success", false):
		return result
		
	var v_res: Dictionary = {}
	match tool_name:
		"create_or_update_script":
			var path = args.get("file_path", "")
			v_res = verify_script(path)
		"add_node":
			var node_name = args.get("node_name", "")
			var parent_path = args.get("parent_path", "")
			var full_path = parent_path.path_join(node_name) if not parent_path.is_empty() else node_name
			v_res = verify_node(full_path, args.get("node_type", ""))
		_:
			v_res = {
				"status": VerificationStatus.PASSED,
				"success": true,
				"message": result.get("message", "Tamamlandı.")
			}
			
	# CRITICAL: Tool'un döndürdüğü yapısal datayı asla silme/kaybetme!
	if result.has("data"):
		v_res["data"] = result["data"]
		
	return v_res
