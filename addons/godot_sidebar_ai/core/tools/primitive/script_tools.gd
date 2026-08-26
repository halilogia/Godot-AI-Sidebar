@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarScriptTools

## İlkel Script (GDScript) ve Kod Araçları (File-First Atomic & Dependency-Aware Batch Editing) (SRP).

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")

static func get_schemas() -> Array:
	return [
		{
			"type": "function",
			"function": {
				"name": "read_script",
				"description": "Belirtilen GDScript, shader veya metin dosyasının tüm içeriğini satır satır okur.",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": { "type": "string", "description": "Dosya yolu (örn: res://scripts/Player.gd)." }
					},
					"required": ["file_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "create_or_update_script",
				"description": "Bir GDScript veya metin dosyasını atomik olarak oluşturur veya günceller. Kod diske yazılmadan önce bellekte sözdizimi doğrulamasından geçirilir.",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": { "type": "string", "description": "Dosya yolu (örn: res://scripts/Player.gd)." },
						"content": { "type": "string", "description": "Yazılacak GDScript kodu." }
					},
					"required": ["file_path", "content"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "write_files",
				"description": "Birden fazla script veya sahne dosyasını tek atomik operasyonda toplu olarak oluşturur veya günceller. Bağımlılıklar (ExtResource ve GDScript) batch içinde otomatik çözümlenir.",
				"parameters": {
					"type": "object",
					"properties": {
						"files": {
							"type": "array",
							"description": "Yazılacak dosyaların listesi. Her öğe 'file_path' ve 'content' alanlarına sahiptir.",
							"items": {
								"type": "object",
								"properties": {
									"file_path": { "type": "string", "description": "Dosya yolu (örn: res://scripts/Player.gd veya res://scenes/Player.tscn)." },
									"content": { "type": "string", "description": "Dosya metin içeriği." }
								},
								"required": ["file_path", "content"]
							}
						}
					},
					"required": ["files"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "open_script",
				"description": "Belirtilen script dosyasını Godot Script Editöründe açar.",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": { "type": "string", "description": "Açılacak script yolu (örn: res://scripts/Player.gd)." }
					},
					"required": ["file_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "validate_script",
				"description": "Bir GDScript dosyasının derlenip derlenmediğini ve syntax hatalarını kontrol eder.",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": { "type": "string", "description": "Kontrol edilecek script yolu." }
					},
					"required": ["file_path"]
				}
			}
		}
	]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"read_script":
			return _read_script(args)
		"create_or_update_script":
			return _create_or_update_script(args)
		"write_files":
			return _write_files(args)
		"open_script":
			return _open_script(args)
		"validate_script":
			return _validate_script(args)
		"eval_gdscript":
			return _eval_gdscript(args)
		_:
			return AISidebarToolResult.err("UNKNOWN_TOOL", "Bilinmeyen script aracı: " + tool_name)

static func _read_script(args: Dictionary) -> Dictionary:
	var raw_path = args.get("file_path", "")
	var safe_check = AISidebarPathPolicy.is_safe_to_read(raw_path)
	if not safe_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
		
	var path = safe_check["path"]
	if not FileAccess.file_exists(path):
		return AISidebarToolResult.err("FILE_NOT_FOUND", "Dosya bulunamadı: " + path)
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return AISidebarToolResult.err("READ_ERROR", "Dosya okunamadı: " + path)
		
	var content = file.get_as_text()
	file.close()
	return AISidebarToolResult.ok({"file_path": path, "content": content})

static func _create_or_update_script(args: Dictionary) -> Dictionary:
	var raw_path = args.get("file_path", "")
	var content = args.get("content", "")
	
	var safe_check = AISidebarPathPolicy.is_safe_to_write(raw_path)
	if not safe_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
		
	var path = safe_check["path"]
	
	# 1. ATOMIC PRE-WRITE VALIDATION
	if path.ends_with(".gd"):
		var val_res = AISidebarVerificationPipeline.validate_script_source(content, path)
		if not val_res.get("success", false):
			var err_obj = val_res.get("error", {})
			return AISidebarToolResult.err(
				err_obj.get("code", "SCRIPT_SYNTAX_ERROR"),
				err_obj.get("message", "Script sözdizimi hatası içeriyor."),
				true,
				err_obj
			)
			
	# 2. WRITE TO DISK
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return AISidebarToolResult.err("WRITE_ERROR", "Dosya yazılamadı: " + path)
	file.store_string(content)
	file.close()
	
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
		if EditorInterface.has_method("get_resource_filesystem"):
			EditorInterface.get_resource_filesystem().scan()
		var res = load(path)
		if res is Script and EditorInterface.has_method("edit_script"):
			EditorInterface.edit_script(res)
			
	return AISidebarToolResult.ok({"file_path": path}, "✓ Script başarıyla yazıldı.")

static func _write_files(args: Dictionary) -> Dictionary:
	var files_arr = args.get("files", [])
	if not (files_arr is Array) or files_arr.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENTS", "Yazılacak dosyalar listesi ('files') boş veya geçersiz.")
		
	# 1. Aşama: Bağımlılık Duyarlı Toplu Doğrulama (Dependency-Aware Pre-validation)
	var val_res = AISidebarVerificationPipeline.validate_batch_files(files_arr)
	if not val_res.get("success", false):
		var err_obj = val_res.get("error", {})
		return AISidebarToolResult.err(
			err_obj.get("code", "BATCH_VALIDATION_ERROR"),
			err_obj.get("message", "Toplu doğrulama başarısız oldu."),
			true,
			err_obj
		)
		
	var sorted_files = val_res.get("sorted_files", files_arr)
	
	# 2. Aşama: Güvenli Sırayla Diske Yazım
	var written_paths: Array = []
	for f_item in sorted_files:
		var p = AISidebarPathPolicy.normalize_path(f_item.get("file_path", ""))
		var c = f_item.get("content", "")
		var dir_path = p.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
		var f = FileAccess.open(p, FileAccess.WRITE)
		if not f:
			return AISidebarToolResult.err("WRITE_ERROR", "Dosya yazılamadı: " + p)
		f.store_string(c)
		f.close()
		written_paths.append(p)
		
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
		if EditorInterface.has_method("get_resource_filesystem"):
			EditorInterface.get_resource_filesystem().scan()
			
	return AISidebarToolResult.ok({
		"written_count": written_paths.size(),
		"files": written_paths
	}, "✓ " + str(written_paths.size()) + " dosya başarıyla oluşturuldu.")

static func _open_script(args: Dictionary) -> Dictionary:
	var path = AISidebarPathPolicy.normalize_path(args.get("file_path", ""))
	if not FileAccess.file_exists(path):
		return AISidebarToolResult.err("FILE_NOT_FOUND", "Script dosyası bulunamadı: " + path)
		
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
		var res = load(path)
		if res is Script and EditorInterface.has_method("edit_script"):
			EditorInterface.edit_script(res)
			return AISidebarToolResult.ok({"file_path": path}, "Script editörde açıldı: " + path)
			
	return AISidebarToolResult.err("EDITOR_REQUIRED", "Script açma editör gerektirir.")

static func _validate_script(args: Dictionary) -> Dictionary:
	var raw_path = args.get("file_path", "")
	return AISidebarVerificationPipeline.verify_script(raw_path)

static func _eval_gdscript(args: Dictionary) -> Dictionary:
	var code = args.get("code", "")
	var expr = Expression.new()
	var err = expr.parse(code)
	if err != OK:
		return AISidebarToolResult.err("PARSE_ERROR", "İfade ayrıştırılamadı: " + expr.get_error_text())
		
	var root: Object = null
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_edited_scene_root"):
		root = EditorInterface.get_edited_scene_root()
		
	var dummy_node: Node = null
	if root == null:
		dummy_node = Node.new()
		root = dummy_node
		
	var result = expr.execute([], root)
	var has_failed = expr.has_execute_failed()
	var err_txt = expr.get_error_text()
	
	if dummy_node != null:
		dummy_node.free()
		
	if has_failed:
		return AISidebarToolResult.err("EXECUTION_ERROR", "Çalıştırma hatası: " + err_txt)
		
	return AISidebarToolResult.ok({"result": str(result)})
