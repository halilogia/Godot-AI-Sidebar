@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarScriptTools

## İlkel Script (GDScript) ve Kod Araçları (File-First Atomic & Dependency-Aware Batch Editing) (SRP).

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarSceneTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/scene_tools.gd")

static func get_schemas() -> Array:
	return [
		{
			"type": "function",
			"function": {
				"name": "read_script",
				"description": "Reads the full content of a GDScript, shader or text file.",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": { "type": "string", "description": "File path (e.g. res://scripts/Player.gd)." }
					},
					"required": ["file_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "create_or_update_script",
				"description": "Creates or updates a GDScript or text file atomically. The code is validated in memory before it is written.",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": { "type": "string", "description": "File path (e.g. res://scripts/Player.gd)." },
						"content": { "type": "string", "description": "GDScript code to write." }
					},
					"required": ["file_path", "content"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "delete_file",
				"description": "Safely deletes a script, scene or file from the project. Needs user approval and can be undone through the change set.",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": { "type": "string", "description": "Path of the file to delete (e.g. res://scripts/OldScript.gd)." },
						"reason": { "type": "string", "description": "Why the file is deleted." }
					},
					"required": ["file_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "write_files",
				"description": "Creates or updates several script or scene files in one atomic batch. Dependencies between them (ExtResource, GDScript) are resolved inside the batch.",
				"parameters": {
					"type": "object",
					"properties": {
						"files": {
							"type": "array",
							"description": "Files to write. Each item has 'file_path' and 'content'.",
							"items": {
								"type": "object",
								"properties": {
									"file_path": { "type": "string", "description": "File path (e.g. res://scripts/Player.gd or res://scenes/Player.tscn)." },
									"content": { "type": "string", "description": "File text content." }
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
				"description": "Opens the given script in the Godot script editor.",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": { "type": "string", "description": "Path of the script to open (e.g. res://scripts/Player.gd)." }
					},
					"required": ["file_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "validate_script",
				"description": "Checks GDScript compilation in the current editor context, including statically resolved types. Does not execute the script or prove runtime behavior or a clean-cache dependency build. Sync changed files first; run headless tests for runtime and dependency verification.",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": { "type": "string", "description": "Path of the script to check." }
					},
					"required": ["file_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "replace_file_content",
				"description": "Surgically replaces one code block in an existing file. Use it to change only the part that changes instead of rewriting the whole file.",
				"parameters": {
					"type": "object",
					"properties": {
						"file_path": { "type": "string", "description": "Path of the file to change (e.g. res://scripts/Player.gd)." },
						"target_code": { "type": "string", "description": "Existing code block; must match the file exactly." },
						"replacement_code": { "type": "string", "description": "New code block that replaces the target." }
					},
					"required": ["file_path", "target_code", "replacement_code"]
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
		"replace_file_content":
			return _replace_file_content(args)
		"delete_file":
			return _delete_file(args)
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
	
	# Diske yazmadan önce in-memory validation (Unified Pipeline)
	var val_res = AISidebarVerificationPipeline.validate_source(content, path)
	if not val_res.get("success", false):
		var err_obj = val_res.get("error", {})
		var err_code = err_obj.get("code", "VALIDATION_FAILED") if err_obj is Dictionary else "VALIDATION_FAILED"
		var err_msg = err_obj.get("message", "Doğrulama hatası") if err_obj is Dictionary else str(val_res.get("error", "Doğrulama hatası"))
		return AISidebarToolResult.err(err_code, "Dosya doğrulaması başarısız, diske yazılmadı: " + err_msg, false, val_res)
			
	var old_content = ""
	var is_new = not FileAccess.file_exists(path)
	if not is_new:
		var old_file = FileAccess.open(path, FileAccess.READ)
		if old_file:
			old_content = old_file.get_as_text()
			old_file.close()
			
	var c_type = AISidebarChangeSet.ChangeType.CREATE_FILE if is_new else AISidebarChangeSet.ChangeType.MODIFY_FILE
	var cs = AISidebarChangeSet.new(path, c_type, content, old_content, "Script oluşturuldu/güncellendi: " + path)
	var apply_res = cs.apply()
	
	if not apply_res["success"]:
		return AISidebarToolResult.err("WRITE_ERROR", apply_res["error"])
		
	var res = AISidebarToolResult.ok({
		"file_path": path,
		"is_new": is_new,
		"message": "Script başarıyla yazıldı (" + ("Yeni" if is_new else "Güncellendi") + "): " + path
	})
	res["change_set"] = cs
	# Açık .tscn üzerine yazıldıysa editör state'ini diskten yenile (stale save önlenir).
	var sync_res = AISidebarSceneTools.refresh_open_scenes([path])
	if res.get("data") is Dictionary:
		(res["data"] as Dictionary)["editor_scene_refreshed"] = (sync_res as Dictionary).get("refreshed", [])
	return res

static func _replace_file_content(args: Dictionary) -> Dictionary:
	var raw_path = args.get("file_path", "")
	var target_code = args.get("target_code", "")
	var replacement_code = args.get("replacement_code", "")
	
	if target_code.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "target_code parametresi boş olamaz.")
		
	var safe_check = AISidebarPathPolicy.is_safe_to_write(raw_path)
	if not safe_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
		
	var path = safe_check["path"]
	if not FileAccess.file_exists(path):
		return AISidebarToolResult.err("FILE_NOT_FOUND", "Değiştirilecek dosya bulunamadı: " + path)
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return AISidebarToolResult.err("READ_ERROR", "Dosya okunamadı: " + path)
		
	var old_content = file.get_as_text()
	file.close()
	
	# 1. Eşleşme kontrolü (0 eşleşme, 1 eşleşme, >1 eşleşme)
	var first_idx = old_content.find(target_code)
	if first_idx == -1:
		return AISidebarToolResult.err("TARGET_NOT_FOUND", "Hedef kod bloğu dosyada bulunamadı: " + path)
		
	var second_idx = old_content.find(target_code, first_idx + target_code.length())
	if second_idx != -1:
		var occurrences = 0
		var pos = 0
		while true:
			pos = old_content.find(target_code, pos)
			if pos == -1:
				break
			occurrences += 1
			pos += target_code.length()
			
		return AISidebarToolResult.err(
			"MULTIPLE_TARGETS_FOUND",
			"Hedef kod dosyada birden fazla kez (" + str(occurrences) + " kez) bulundu. Lütfen etrafındaki satırları da ekleyerek hedefi daha spesifik belirtin: " + path
		)
		
	# 2. Cerrahi Değiştirme (Surgical Replacement)
	var new_content = old_content.substr(0, first_idx) + replacement_code + old_content.substr(first_idx + target_code.length())
	
	# 3. Diske yazmadan önce in-memory validation (Unified Pipeline)
	var val_res = AISidebarVerificationPipeline.validate_source(new_content, path)
	if not val_res.get("success", false):
		var err_obj = val_res.get("error", {})
		var err_code = err_obj.get("code", "VALIDATION_FAILED") if err_obj is Dictionary else "VALIDATION_FAILED"
		var err_msg = err_obj.get("message", "Doğrulama hatası") if err_obj is Dictionary else str(val_res.get("error", "Doğrulama hatası"))
		return AISidebarToolResult.err(err_code, "Değişiklik sonrası doğrulama başarısız, dosya değiştirilmedi: " + err_msg, false, val_res)
			
	# 4. ChangeSet oluştur ve uygula
	var cs = AISidebarChangeSet.new(
		path,
		AISidebarChangeSet.ChangeType.MODIFY_FILE,
		new_content,
		old_content,
		"Cerrahi kod güncellemesi: " + path
	)
	var apply_res = cs.apply()
	if not apply_res["success"]:
		return AISidebarToolResult.err("WRITE_ERROR", apply_res["error"])
		
	var old_hash = old_content.md5_text()
	var new_hash = new_content.md5_text()
	var diff_text = cs.get_diff_text()
	
	var res = AISidebarToolResult.ok({
		"file_path": path,
		"replacements": 1,
		"old_content_hash": old_hash,
		"new_content_hash": new_hash,
		"diff": diff_text,
		"message": "Kod bloğu cerrahi olarak başarıyla güncellendi: " + path
	})
	res["change_set"] = cs
	var sync_rep = AISidebarSceneTools.refresh_open_scenes([path])
	if res.get("data") is Dictionary:
		(res["data"] as Dictionary)["editor_scene_refreshed"] = (sync_rep as Dictionary).get("refreshed", [])
	return res

static func _delete_file(args: Dictionary) -> Dictionary:
	var raw_path = args.get("file_path", "")
	var reason = args.get("reason", "Dosya silme işlemi")
	
	var safe_check = AISidebarPathPolicy.is_safe_to_write(raw_path)
	if not safe_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
		
	var path = safe_check["path"]
	if not FileAccess.file_exists(path):
		return AISidebarToolResult.err("FILE_NOT_FOUND", "Silinecek dosya bulunamadı: " + path)
		
	var old_file = FileAccess.open(path, FileAccess.READ)
	var old_content = old_file.get_as_text() if old_file else ""
	if old_file:
		old_file.close()
		
	var cs = AISidebarChangeSet.new(path, AISidebarChangeSet.ChangeType.DELETE_FILE, "", old_content, reason)
	var apply_res = cs.apply()
	if not apply_res.get("success", false):
		return AISidebarToolResult.err("DELETE_FAILED", "Dosya silinemedi: " + apply_res.get("error", "Bilinmeyen hata"))
		
	var res = AISidebarToolResult.ok({
		"file_path": path,
		"deleted": true,
		"message": "Dosya başarıyla silindi: " + path
	})
	res["change_set"] = cs
	return res

static func _write_files(args: Dictionary) -> Dictionary:
	var files_arr = args.get("files", [])
	if not (files_arr is Array) or files_arr.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "'files' listesi boş veya geçersiz.")
		
	var val_res = AISidebarVerificationPipeline.validate_batch_files(files_arr)
	if not val_res.get("success", false):
		var err_obj = val_res.get("error", {})
		var err_code = err_obj.get("code", "BATCH_VALIDATION_FAILED") if err_obj is Dictionary else "BATCH_VALIDATION_FAILED"
		var err_msg = err_obj.get("message", "Doğrulama hatası") if err_obj is Dictionary else str(val_res.get("error", "Doğrulama hatası"))
		return AISidebarToolResult.err(err_code, "Toplu dosya yazımı doğrulanamadı: " + err_msg, false, val_res)
		
	var files_to_write: Array[Dictionary] = []
	for f_item in files_arr:
		if not (f_item is Dictionary): continue
		var raw_path = f_item.get("file_path", "")
		var content = f_item.get("content", "")
		var check = AISidebarPathPolicy.is_safe_to_write(raw_path)
		if not check["safe"]:
			return AISidebarToolResult.err("PERMISSION_DENIED", "Güvenlik engeli: " + check["reason"] + " (" + raw_path + ")")
		files_to_write.append({
			"path": check["path"],
			"content": content
		})
		
	if files_to_write.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "Yazılacak geçerli dosya bulunamadı.")
		
	var first = files_to_write[0]
	var first_is_new = not FileAccess.file_exists(first["path"])
	var first_old_content = ""
	if not first_is_new:
		var f = FileAccess.open(first["path"], FileAccess.READ)
		if f:
			first_old_content = f.get_as_text()
			f.close()
			
	var first_type = AISidebarChangeSet.ChangeType.CREATE_FILE if first_is_new else AISidebarChangeSet.ChangeType.MODIFY_FILE
	var main_cs = AISidebarChangeSet.new(first["path"], first_type, first["content"], first_old_content, "Toplu dosya yazımı")
	
	for i in range(1, files_to_write.size()):
		var item = files_to_write[i]
		var is_new = not FileAccess.file_exists(item["path"])
		var old_c = ""
		if not is_new:
			var f2 = FileAccess.open(item["path"], FileAccess.READ)
			if f2:
				old_c = f2.get_as_text()
				f2.close()
		var sub_type = AISidebarChangeSet.ChangeType.CREATE_FILE if is_new else AISidebarChangeSet.ChangeType.MODIFY_FILE
		main_cs.add_sub_change(item["path"], sub_type, item["content"], old_c, "Toplu dosya parçası: " + item["path"])
		
	var apply_res = main_cs.apply()
	if not apply_res["success"]:
		return AISidebarToolResult.err("BATCH_WRITE_FAILED", apply_res["error"])
		
	var written_paths: Array = files_to_write.map(func(x): return x["path"])
	var res = AISidebarToolResult.ok({
		"count": files_to_write.size(),
		"written_files": written_paths,
		"message": str(files_to_write.size()) + " dosya atomik olarak başarıyla yazıldı."
	})
	res["change_set"] = main_cs
	# Açık .tscn'ler diskten yenilenir; sonraki save_scene stale yazmaz.
	var sync_w = AISidebarSceneTools.refresh_open_scenes(written_paths)
	if res.get("data") is Dictionary:
		(res["data"] as Dictionary)["editor_scene_refreshed"] = (sync_w as Dictionary).get("refreshed", [])
	return res

static func _open_script(args: Dictionary) -> Dictionary:
	var raw_path = args.get("file_path", "")
	var safe_check = AISidebarPathPolicy.is_safe_to_read(raw_path)
	if not safe_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
		
	var path = safe_check["path"]
	if not FileAccess.file_exists(path):
		return AISidebarToolResult.err("FILE_NOT_FOUND", "Script bulunamadı: " + path)
		
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
		var script_res = load(path)
		if script_res:
			EditorInterface.edit_script(script_res)
			return AISidebarToolResult.ok({"file_path": path, "opened": true})
			
	return AISidebarToolResult.err("EDITOR_UNAVAILABLE", "EditorInterface hazır değil.")

static func _validate_script(args: Dictionary) -> Dictionary:
	if not args.get("file_path") is String or str(args.get("file_path", "")).strip_edges().is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "Required argument: file_path (non-empty string). Read the tool schema before calling.")
	var raw_path = args.get("file_path", "")
	var safe_check = AISidebarPathPolicy.is_safe_to_read(raw_path)
	if not safe_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
		
	var path = safe_check["path"]
	if not FileAccess.file_exists(path):
		return AISidebarToolResult.err("FILE_NOT_FOUND", "Script bulunamadı: " + path)
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return AISidebarToolResult.err("READ_ERROR", "Dosya okunamadı: " + path)
	var content = file.get_as_text()
	file.close()
	
	var val_res: Dictionary = AISidebarVerificationPipeline.validate_script_source(content, str(path))
	val_res["validation_scope"] = "in_memory_compilation"
	val_res["runtime_verified"] = false
	val_res["dependency_build_verified"] = false
	if not val_res.get("success", false):
		var error: Dictionary = val_res.get("error", {})
		return AISidebarToolResult.err(str(error.get("code", "SCRIPT_SYNTAX_ERROR")), str(error.get("message", "Compilation failed.")), true, val_res)
	return AISidebarToolResult.ok(val_res)

static func _eval_gdscript(args: Dictionary) -> Dictionary:
	var code = args.get("code", "")
	if code.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "Çalıştırılacak kod boş.")
		
	var exec_code = code.strip_edges()
	if not "\n" in exec_code and not exec_code.begins_with("return "):
		exec_code = "return " + exec_code
		
	var val_res = AISidebarVerificationPipeline.validate_script_source("func _eval_test():\n\t" + exec_code.replace("\n", "\n\t"))
	if not val_res.get("success", false):
		return AISidebarToolResult.err("SYNTAX_ERROR", "Değerlendirilecek kodda sözdizimi hatası: " + str(val_res.get("error", "Hata")))
		
	var script = GDScript.new()
	script.source_code = "@tool\nextends RefCounted\nfunc run():\n\t" + exec_code.replace("\n", "\n\t")
	var err = script.reload()
	if err != OK:
		return AISidebarToolResult.err("COMPILE_ERROR", "Kod derlenemedi: " + str(err))
		
	var instance = script.new()
	if not instance:
		return AISidebarToolResult.err("INSTANTIATE_ERROR", "Script örneği oluşturulamadı.")
		
	var result = instance.call("run")
	return AISidebarToolResult.ok({"result": str(result)})
