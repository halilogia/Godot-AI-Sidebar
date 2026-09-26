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
	script.source_code = _without_own_class_name(source_code, file_path)
	var reload_err = script.reload()
	
	if reload_err != OK:
		# Hata, henüz diske yazılmamış bir batch dosyasına referanstan kaynaklanıyor
		# olabilir: batch geçici bir aynaya yazılıp betik gerçekten derlenir.
		# Böylece gerçek sözdizimi / üye hataları istisnaya saklanamaz.
		if reload_err == ERR_PARSE_ERROR or reload_err == ERR_FILE_NOT_FOUND:
			if _references_batch_file(source_code, file_path, batch_context) and _compile_with_batch_mirror(source_code, batch_context) == OK:
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

## Yolsuz geçici kopya, kendi dosyasına kayıtlı `class_name X`'i derlerken Godot "Class X hides a
## global script class" (ERR_PARSE_ERROR = 43) der; oysa dosya geçerlidir. Sınıf tam bu dosyaya
## kayıtlıysa satır, satır numaraları kaymasın diye yoruma çevrilir. Başka bir dosyaya kayıtlı aynı
## ad gerçek çakışmadır ve dokunulmaz. (Geçici script'e yol vermek, set_path_cache, kaynak
## önbelleğinde gerçek script'in yerini aldığı için kullanılmaz.)
static func _without_own_class_name(source_code: String, file_path: String) -> String:
	if file_path.is_empty():
		return source_code
	var re := RegEx.new()
	re.compile("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var m := re.search(source_code)
	if m == null:
		return source_code
	var cls := m.get_string(1)
	var wanted := _res_path(file_path)
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == cls:
			if _res_path(str(entry.get("path", ""))) == wanted:
				return source_code.substr(0, m.get_start()) + "#" + source_code.substr(m.get_start())
			return source_code
	return source_code

static func _res_path(p: String) -> String:
	var s := p.strip_edges().replace("\\", "/")
	if not s.begins_with("res://"):
		s = "res://" + s.trim_prefix("/")
	return s.simplify_path()

## Batch aynası: derleme sırasında batch dosyalarının geçici kopyaları (proje dışı).
const BATCH_MIRROR_ROOT = "user://ai_sidebar_verify"
static var _mirror_seq: int = 0

## Kaynak, kendisi dışındaki bir batch dosyasını tırnaklı yol olarak anıyor mu?
static func _references_batch_file(source_code: String, file_path: String, batch_context: Dictionary) -> bool:
	for bp in batch_context.keys():
		var p = str(bp)
		if p == file_path:
			continue
		if ("\"" + p + "\"") in source_code or ("'" + p + "'") in source_code:
			return true
	return false

## Batch dosyalarını geçici aynaya yazar, batch yollarını aynaya çevirip betiği
## derler, aynayı siler. Dönen değer derleme sonucudur.
static func _compile_with_batch_mirror(source_code: String, batch_context: Dictionary) -> int:
	_mirror_seq += 1
	var root = BATCH_MIRROR_ROOT + "/%d_%d" % [Time.get_ticks_usec(), _mirror_seq]
	var written: Array = []
	var err: int = OK
	for bp in batch_context.keys():
		var p = str(bp)
		if not p.begins_with("res://"):
			continue
		var target = root + "/" + p.trim_prefix("res://")
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var f = FileAccess.open(target, FileAccess.WRITE)
		if f == null:
			err = ERR_CANT_CREATE
			break
		f.store_string(_rewrite_batch_paths(str(batch_context[bp]), batch_context, root))
		f.close()
		written.append(target)
	if err == OK:
		var mirrored = GDScript.new()
		mirrored.source_code = _rewrite_batch_paths(source_code, batch_context, root)
		err = mirrored.reload()
	for w in written:
		DirAccess.remove_absolute(w)
	_remove_empty_dirs(root)
	_remove_empty_dirs(BATCH_MIRROR_ROOT)
	return err

static func _rewrite_batch_paths(text: String, batch_context: Dictionary, root: String) -> String:
	var out = text
	for bp in batch_context.keys():
		var p = str(bp)
		if not p.begins_with("res://"):
			continue
		var mp = root + "/" + p.trim_prefix("res://")
		out = out.replace("\"" + p + "\"", "\"" + mp + "\"").replace("'" + p + "'", "'" + mp + "'")
	return out

## Yalnızca boş klasörleri siler (alttan üste); dosya içeren klasöre dokunmaz.
static func _remove_empty_dirs(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_remove_empty_dirs(path.path_join(d))
	if DirAccess.get_directories_at(path).is_empty() and DirAccess.get_files_at(path).is_empty():
		DirAccess.remove_absolute(path)

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
