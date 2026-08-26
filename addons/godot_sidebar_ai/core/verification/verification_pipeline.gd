@tool
extends RefCounted
class_name AISidebarVerificationPipeline

## Üç Durumlu Genişletilmiş Doğrulama Hattı (Three-State Verification Pipeline) (SRP).
## Sonuçları kesinlikle PASSED, FAILED veya INCONCLUSIVE olarak sınıflandırır.

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarVisualObservation = preload("res://addons/godot_sidebar_ai/core/types/visual_observation.gd")

enum VerificationStatus {
	PASSED,
	FAILED,
	INCONCLUSIVE
}

## Script sözdizimi ve derleme doğrulaması
static func verify_script(raw_path: String) -> Dictionary:
	var path = AISidebarPathPolicy.normalize_path(raw_path)
	if not FileAccess.file_exists(path):
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {"code": "FILE_NOT_FOUND", "message": "Doğrulama başarısız: Script dosyası bulunamadı: " + path}
		}
		
	var script_res = load(path)
	if not script_res or not (script_res is Script):
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {"code": "SYNTAX_ERROR", "message": "Doğrulama başarısız: Script derlenemedi, sözdizimi hatası mevcut."}
		}
		
	return {
		"status": VerificationStatus.PASSED,
		"success": true,
		"message": "✓ Script başarıyla doğrulandı ve derlendi."
	}

## Sahnede düğümün varlığını ve tipini doğrulama
static func verify_node(node_path: String, expected_class: String = "") -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface") or not EditorInterface.has_method("get_edited_scene_root"):
		return {
			"status": VerificationStatus.INCONCLUSIVE,
			"success": true,
			"message": "Editör dışı ortamda doğrulama belirsiz (INCONCLUSIVE)."
		}
		
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return {
			"status": VerificationStatus.INCONCLUSIVE,
			"success": false,
			"error": {"code": "NO_ACTIVE_SCENE", "message": "Aktif açık sahne yok."}
		}
		
	if not root.has_node(node_path):
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {"code": "NODE_NOT_FOUND", "message": "Doğrulama başarısız: Sahnede beklenen düğüm bulunamadı: " + node_path}
		}
		
	var node = root.get_node(node_path)
	if not expected_class.is_empty() and not node.is_class(expected_class):
		return {
			"status": VerificationStatus.FAILED,
			"success": false,
			"error": {"code": "TYPE_MISMATCH", "message": "Düğüm tipi beklenenle eşleşmiyor. Beklenen: " + expected_class + ", Gerçek: " + node.get_class()}
		}
		
	return {
		"status": VerificationStatus.PASSED,
		"success": true,
		"message": "✓ Düğüm sahnede doğrulandı."
	}

## Görsel Gözlem Doğrulaması (Visual Verification)
static func verify_visual_observation(visual_obs: AISidebarVisualObservation) -> Dictionary:
	if visual_obs == null:
		return {
			"status": VerificationStatus.INCONCLUSIVE,
			"success": false,
			"error": {"code": "NO_VISUAL_DATA", "message": "Görsel gözlem verisi bulunamadı (INCONCLUSIVE)."}
		}
		
	if not visual_obs.is_confident():
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

## Bir araç icrasından sonra otomatik verification çalıştırır
static func auto_verify_tool_execution(tool_name: String, args: Dictionary, result: Dictionary) -> Dictionary:
	if not result.get("success", false):
		return result
		
	match tool_name:
		"create_or_update_script":
			var path = args.get("file_path", "")
			return verify_script(path)
		"add_node":
			var node_name = args.get("node_name", "")
			var parent_path = args.get("parent_path", "")
			var full_path = parent_path.path_join(node_name) if not parent_path.is_empty() else node_name
			return verify_node(full_path, args.get("node_type", ""))
		_:
			return {
				"status": VerificationStatus.PASSED,
				"success": true,
				"message": result.get("message", "Tamamlandı.")
			}
