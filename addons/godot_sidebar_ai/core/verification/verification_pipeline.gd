@tool
extends RefCounted
class_name AISidebarVerificationPipeline

## Üç Durumlu Doğrulama ve Güvenilirlik Boru Hattı (SRP).
## PASSED, FAILED ve INCONCLUSIVE durumlarını ve otomatik tool verification adımlarını yönetir.

const AISidebarVisualObservation = preload("res://addons/godot_sidebar_ai/core/types/visual_observation.gd")

enum VerificationStatus {
	PASSED,
	FAILED,
	INCONCLUSIVE
}

const CONFIDENCE_THRESHOLD: float = 0.65

## 1. Bellek İçi Kaynak Kodu Doğrulaması (Pre-write In-Memory Validation)
static func validate_script_source(source_code: String, file_path: String = "") -> Dictionary:
	var script = GDScript.new()
	script.source_code = source_code
	var reload_err = script.reload()
	if reload_err != OK:
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {
				"code": "SCRIPT_SYNTAX_ERROR",
				"message": "Script sözdizimi (syntax) hatası içeriyor (Derleme kodu: " + str(reload_err) + "). Dosya yolu: " + file_path,
				"file_path": file_path,
				"recoverable": true
			}
		}
	if not script.can_instantiate():
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {
				"code": "SCRIPT_COMPILE_ERROR",
				"message": "Script başarıyla örneklenemedi veya geçersiz referanslara sahip: " + file_path,
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
		
	var script_res = load(file_path)
	if script_res == null or not (script_res is Script):
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {"code": "SCRIPT_LOAD_ERROR", "message": "Script yüklenemedi veya geçersiz GDScript: " + file_path, "file_path": file_path, "recoverable": true}
		}
		
	if not script_res.can_instantiate():
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {"code": "SCRIPT_SYNTAX_ERROR", "message": "Script derlenemiyor (Syntax hatası): " + file_path, "file_path": file_path, "recoverable": true}
		}
		
	return {
		"status": VerificationStatus.PASSED,
		"success": true,
		"message": "✓ Script doğrulandı: " + file_path
	}

## 3. Sahne / Düğüm Doğrulaması (Node Hierarchy Verification)
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

## 4. Görsel Doğrulama (Visual Verification with Confidence Threshold)
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
