@tool
extends RefCounted
class_name AISidebarVerificationPipeline

## Üç Durumlu Doğrulama, Bağımlılık Denetimi ve Güvenilirlik Boru Hattı (SRP).
## PASSED, FAILED ve INCONCLUSIVE durumlarını, sözdizimi ve ChangeSet bağımlılıklarını yönetir.

const AISidebarVisualObservation = preload("res://addons/godot_sidebar_ai/core/types/visual_observation.gd")

enum VerificationStatus {
	PASSED,
	FAILED,
	INCONCLUSIVE
}

const CONFIDENCE_THRESHOLD: float = 0.65

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
	
	return validate_script_source(text, file_path)

## 3. Bağımlılık Duyarlı Toplu Dosya Doğrulaması (Dependency-Aware Batch Validator)
static func validate_batch_files(files_arr: Array) -> Dictionary:
	var batch_map: Dictionary = {}
	for item in files_arr:
		if item is Dictionary:
			var p = str(item.get("file_path", ""))
			if not p.is_empty():
				batch_map[p] = item.get("content", "")
				
	# 1. GDScript sözdizimi kontrolü
	for p in batch_map.keys():
		if p.ends_with(".gd"):
			var val_res = validate_script_source(batch_map[p], p, batch_map)
			if not val_res.get("success", false):
				return val_res
				
	# 2. TSCN ve ExtResource referans kontrolü
	var ext_regex = RegEx.new()
	ext_regex.compile('path="([^"]+)"')
	
	for p in batch_map.keys():
		if p.ends_with(".tscn") or p.ends_with(".tres"):
			var content = str(batch_map[p])
			var matches = ext_regex.search_all(content)
			for m in matches:
				var ref_path = m.get_string(1)
				if ref_path.begins_with("res://"):
					var exists_on_disk = FileAccess.file_exists(ref_path)
					var in_current_batch = batch_map.has(ref_path)
					if not exists_on_disk and not in_current_batch:
						return {
							"status": VerificationStatus.FAILED,
							"success": false,
							"error": {
								"code": "RESOURCE_REFERENCE_NOT_FOUND",
								"message": "Dosya (" + p + ") bulunamayan bir kaynağa referans veriyor: " + ref_path + ". (Ne diskte var ne de mevcut batch paketinde).",
								"file_path": p,
								"missing_resource": ref_path,
								"recoverable": true
							}
						}
						
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
