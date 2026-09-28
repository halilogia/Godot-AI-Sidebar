@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarScriptTools

## İlkel Script (GDScript) ve Kod Araçları (File-First Atomic & Dependency-Aware Batch Editing) (SRP).

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")
const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarSceneTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/scene_tools.gd")
const AISidebarProjectValidator = preload("res://addons/godot_sidebar_ai/core/verification/project_validator.gd")

## Görev boyunca yazma durumu: engelleyici (sözdizimi) hatayla reddedilip diske hiç yazılmayan dosyalar
## (yol → neden) ve derlenmeden yazılan dosyalar (yol → hata). Reddedilen dosyayı yamamaya kalkan ajana
## neden söylenir (file_info da gösterir); hatalı dosya kalmışken görev tamam sayılmaz.
static var rejected_writes: Dictionary = {}
static var files_with_errors: Dictionary = {}

static func reset_write_state() -> void:
	rejected_writes.clear()
	files_with_errors.clear()

## Kayıtlar diskten yeniden denetlenir: bağımlılığı sonradan yazılan dosya artık derlenebilir,
## reddedilen dosya başka yolla yazılmış ya da hatalı dosya silinmiş olabilir.
static func refresh_write_state() -> void:
	for p: String in files_with_errors.keys():
		if not FileAccess.file_exists(p):
			files_with_errors.erase(p)
			continue
		var v: Dictionary = AISidebarVerificationPipeline.verify_script(p)
		if v.get("success", false):
			files_with_errors.erase(p)
		else:
			files_with_errors[p] = AISidebarVerificationPipeline.error_message(v)
	for p: String in rejected_writes.keys():
		if FileAccess.file_exists(p):
			rejected_writes.erase(p)

## Açık yazma sorunları (derlenmeyen / reddedilip yazılmamış dosyalar) model için tek metin; yoksa "".
static func open_write_problems() -> String:
	refresh_write_state()
	var parts := PackedStringArray()
	if not files_with_errors.is_empty():
		parts.append("Files on disk that do not compile: " + "; ".join(_pairs(files_with_errors)) + ".")
	if not rejected_writes.is_empty():
		parts.append("Files you wrote that were rejected and are NOT on disk: " + "; ".join(_pairs(rejected_writes)) + ".")
	return " ".join(parts)

static func _note_write(path: String, verify_error: String) -> void:
	rejected_writes.erase(path)
	if verify_error.is_empty():
		files_with_errors.erase(path)
	else:
		files_with_errors[path] = verify_error

## Engelleyici hatayla reddedilen yazım: makine-okunur alanlar + ajan için kurtarma yolu.
static func _reject_write(path: String, reason: String, val_res: Dictionary) -> Dictionary:
	var existed := FileAccess.file_exists(path)
	if not existed:
		rejected_writes[path] = reason
	var disk := "UNCHANGED (the previous version is still on disk)" if existed else "MISSING (this file does NOT exist on disk)"
	var code := AISidebarVerificationPipeline.error_code(val_res)
	var msg := "WRITE_REJECTED: %s was NOT written; %s. Disk: %s. Fix the complete source and send it again with create_or_update_script / write_files." % [path, reason, disk]
	if not existed:
		msg += " Do not call replace_file_content: there is no file to patch."
	var errors: Array = []
	var err_v: Variant = val_res.get("error", null)
	if err_v is Dictionary:
		var err: Dictionary = err_v
		var list_v: Variant = err.get("errors", [])
		if list_v is Array:
			errors = list_v
	return AISidebarToolResult.err(code, msg, true, {
		"file_path": path,
		"operation_status": "REJECTED",
		"disk_state": "UNCHANGED" if existed else "MISSING",
		"verification_status": "FAILED",
		"error_class": _error_class(code),
		"retry_strategy": "RESEND_FULL_FILE",
		"errors": errors,
	})

## Yamanacak dosya diskte yok: önceki yazımı reddedildiyse nedeni söylenir (ajan yazıldığını sanıyordu).
static func missing_file_error(path: String) -> Dictionary:
	var data := {"file_path": path, "operation_status": "REJECTED", "disk_state": "MISSING", "retry_strategy": "RESEND_FULL_FILE"}
	if rejected_writes.has(path):
		return AISidebarToolResult.err("FILE_NOT_WRITTEN", "%s does NOT exist on disk: your earlier write of it was rejected (%s), so nothing was written. Send the complete, fixed file with create_or_update_script / write_files." % [path, str(rejected_writes[path])], true, data)
	return AISidebarToolResult.err("FILE_NOT_FOUND", "%s does not exist on disk; replace_file_content only patches existing files. Create it with create_or_update_script / write_files." % path, true, data)

static func _error_class(code: String) -> String:
	return "SYNTAX" if code == "SCRIPT_SYNTAX_ERROR" else "INVALID_RESOURCE"

static func _pairs(d: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k: Variant in d.keys():
		out.append("%s: %s" % [str(k), str(d[k])])
	return out

## Yazılan dosyanın doğrulama alanları (verify_error boşsa temiz).
static func _write_status(data: Dictionary, verify_error: String) -> void:
	data["operation_status"] = "APPLIED"
	data["disk_state"] = "WRITTEN"
	data["verification_status"] = "PASSED" if verify_error.is_empty() else "FAILED"
	if not verify_error.is_empty():
		data["verification_error"] = verify_error
		data["retry_strategy"] = "PATCH_EXISTING"
		data["message"] = "WRITTEN_WITH_ERRORS: the file IS on disk but does not compile yet: %s. Do not recreate it; fix it with replace_file_content (or write the missing dependency). The task is not complete while it has errors." % verify_error

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
				"name": "file_info",
				"description": "Says for certain whether a file exists on disk (size, modified time, line count). If an earlier write of it was rejected, also says why it was never written. Use it before patching a file you are not sure was written.",
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
				"name": "find_files",
				"description": "Finds files by name or path pattern when you do not know the exact path, e.g. '*inventory*.gd' or 'scenes/*.tscn' (* and ? wildcards, case-insensitive; a plain word matches anywhere in the path). Lists paths only: file_info checks one exact path, search_code searches file contents, read_script reads a file.",
				"parameters": {
					"type": "object",
					"properties": {
						"pattern": { "type": "string", "description": "Name or path pattern, e.g. '*player*.tscn', 'enemy', 'scripts/*.gd'." },
						"path": { "type": "string", "description": "Folder to search. Default: res://" },
						"max_results": { "type": "integer", "description": "Maximum paths. Default: 100." }
					},
					"required": ["pattern"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "search_code",
				"description": "Searches the text of project files (.gd, .tscn, .tres, .gdshader, .cfg, .json) and returns file:line matches, e.g. where a class_name is declared or a signal is used. No match does NOT mean a file is missing; use file_info for that.",
				"parameters": {
					"type": "object",
					"properties": {
						"query": { "type": "string", "description": "Text to find (case-insensitive), or a regular expression when regex is true." },
						"path": { "type": "string", "description": "Folder to search. Default: res://" },
						"regex": { "type": "boolean", "description": "Treat query as a regular expression. Default: false." },
						"max_results": { "type": "integer", "description": "Maximum matches. Default: 50." }
					},
					"required": ["query"]
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
				"name": "validate_project",
				"description": "Compiles every GDScript in the project with its real path and project context (class_name, preload, types) and checks that scenes and resources point to existing dependencies. Returns each error with file, line and message, plus scope, engine and duration_ms. Use it after changing several scripts or before claiming the project compiles; validate_script is the quick single-file check. Does not execute scripts or prove runtime behavior.",
				"parameters": {
					"type": "object",
					"properties": {
						"path": { "type": "string", "description": "Optional folder to limit the check (e.g. res://scripts). Default: the whole project." }
					},
					"required": []
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
		"file_info":
			return _file_info(args)
		"search_code":
			return _search_code(args)
		"find_files":
			return _find_files(args)
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
		"validate_project":
			return _validate_project(args)
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

static func _file_info(args: Dictionary) -> Dictionary:
	var safe_check = AISidebarPathPolicy.is_safe_to_read(str(args.get("file_path", "")))
	if not safe_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
	var path: String = safe_check["path"]
	var info := {"file_path": path, "exists": FileAccess.file_exists(path)}
	if info["exists"]:
		var text := FileAccess.get_file_as_string(path)
		info["size_bytes"] = FileAccess.get_file_as_bytes(path).size()
		info["line_count"] = text.count("\n") + 1
		info["modified_unix"] = FileAccess.get_modified_time(path)
		if files_with_errors.has(path):
			info["verification_error"] = files_with_errors[path]
	elif rejected_writes.has(path):
		info["previous_write"] = {"status": "REJECTED", "reason": rejected_writes[path]}
		info["message"] = "Not on disk: its earlier write was rejected and never written. Send the complete, fixed file."
	elif DirAccess.dir_exists_absolute(path):
		info["is_directory"] = true
	return AISidebarToolResult.ok(info)

## Ad / yol kalıbı: * ve ? joker, büyük-küçük harf duyarsız; joker yoksa yolun her yerinde alt metin.
static func path_matches(path: String, pattern: String) -> bool:
	var p := path.to_lower()
	var pat := pattern.to_lower().strip_edges()
	if pat.is_empty():
		return false
	if not ("*" in pat or "?" in pat):
		return p.contains(pat)
	# Kalıp yol içinde herhangi bir yerden başlayabilir (klasör öneki verilmeden 'scenes/*.tscn').
	return p.match(pat) or p.match("*/" + pat) or p.match("*" + pat)

static func _find_files(args: Dictionary) -> Dictionary:
	var pattern := str(args.get("pattern", ""))
	if pattern.strip_edges().is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "pattern boş olamaz.")
	var root := str(args.get("path", "res://"))
	if root.is_empty():
		root = "res://"
	var max_results := maxi(1, int(args.get("max_results", 100)))
	var all: Array[String] = []
	_collect_all_files(root, all)
	all.sort()
	var found: Array = []
	var total := 0
	for f: String in all:
		if path_matches(f, pattern):
			total += 1
			if found.size() < max_results:
				found.append(f)
	var out := {"pattern": pattern, "path": root, "count": total, "files": found, "truncated": total > found.size()}
	if total == 0:
		out["message"] = "No file path matches. The file may not exist, or it was never written (file_info on an exact path says which)."
	return AISidebarToolResult.ok(out)

static func _collect_all_files(dir: String, out: Array[String]) -> void:
	for skip: String in SEARCH_SKIP:
		if dir.begins_with(skip):
			return
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		if not f.ends_with(".import") and not f.ends_with(".uid"):
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		_collect_all_files(dir.path_join(sub), out)

const SEARCH_EXTENSIONS := ["gd", "tscn", "tres", "gdshader", "cfg", "json"]
const SEARCH_SKIP := ["res://.godot", "res://addons/godot_sidebar_ai"]

static func _search_code(args: Dictionary) -> Dictionary:
	var query := str(args.get("query", ""))
	if query.is_empty():
		return AISidebarToolResult.err("INVALID_ARGUMENT", "query boş olamaz.")
	var root := str(args.get("path", "res://"))
	if root.is_empty():
		root = "res://"
	var max_results := maxi(1, int(args.get("max_results", 50)))
	var rx: RegEx = null
	if bool(args.get("regex", false)):
		rx = RegEx.create_from_string("(?i)" + query)
		if rx == null or not rx.is_valid():
			return AISidebarToolResult.err("INVALID_ARGUMENT", "Geçersiz düzenli ifade: " + query)
	var needle := query.to_lower()
	var files: Array[String] = []
	_collect_search_files(root, files)
	var matches: Array = []
	var truncated := false
	for f: String in files:
		var lines := FileAccess.get_file_as_string(f).split("\n")
		for i in lines.size():
			var line: String = lines[i]
			var hit := rx.search(line) != null if rx else line.to_lower().contains(needle)
			if hit:
				if matches.size() >= max_results:
					truncated = true
					break
				matches.append({"file_path": f, "line": i + 1, "text": line.strip_edges().left(200)})
		if truncated:
			break
	var out := {"query": query, "path": root, "files_searched": files.size(), "count": matches.size(), "matches": matches, "truncated": truncated}
	if matches.is_empty():
		out["message"] = "No matching text found. This does NOT mean a file is missing; use file_info to check a specific path."
	return AISidebarToolResult.ok(out)

static func _collect_search_files(dir: String, out: Array[String]) -> void:
	for skip: String in SEARCH_SKIP:
		if dir.begins_with(skip):
			return
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		if f.get_extension() in SEARCH_EXTENSIONS:
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		_collect_search_files(dir.path_join(sub), out)

static func _create_or_update_script(args: Dictionary) -> Dictionary:
	var raw_path = args.get("file_path", "")
	var content = args.get("content", "")
	
	var safe_check = AISidebarPathPolicy.is_safe_to_write(raw_path)
	if not safe_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", safe_check["reason"])
		
	var path = safe_check["path"]
	
	# Diske yazmadan önce in-memory validation (Unified Pipeline): yalnız sözdizimi hatası yazımı engeller.
	var val_res: Dictionary = AISidebarVerificationPipeline.validate_source(content, path)
	var verify_error := ""
	if not val_res.get("success", false):
		if AISidebarVerificationPipeline.blocks_write(val_res):
			return _reject_write(str(path), AISidebarVerificationPipeline.error_message(val_res), val_res)
		verify_error = AISidebarVerificationPipeline.error_message(val_res)

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
	var res_data: Dictionary = res["data"]
	var written_path: String = path
	_write_status(res_data, verify_error)
	_note_write(written_path, verify_error)
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
		return missing_file_error(str(path))

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
	var val_res: Dictionary = AISidebarVerificationPipeline.validate_source(new_content, path)
	var verify_error := ""
	if not val_res.get("success", false):
		if AISidebarVerificationPipeline.blocks_write(val_res):
			return _reject_write(str(path), AISidebarVerificationPipeline.error_message(val_res), val_res)
		verify_error = AISidebarVerificationPipeline.error_message(val_res)

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
	var res_data: Dictionary = res["data"]
	var written_path: String = path
	_write_status(res_data, verify_error)
	_note_write(written_path, verify_error)
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
		
	# Dosya dosya: sözdizimi hatalı olan yazılmaz, derlenmeyen (tanımsız ad / tip / bağımlılık) yazılıp
	# raporlanır, gerisi temiz yazılır. Tek bozuk dosya bütün batch'i silip modeli baştan yazdırıyordu.
	var classes: Dictionary = AISidebarVerificationPipeline.classify_batch(files_arr)
	var rejected_raw: Dictionary = classes["rejected"]
	var codes_raw: Dictionary = classes["codes"]
	var first_code := ""
	var errors_raw: Dictionary = classes["errors"]
	var files_to_write: Array[Dictionary] = []
	var rejected: Dictionary = {}
	var with_errors: Dictionary = {}
	for f_item in files_arr:
		if not (f_item is Dictionary): continue
		var raw_path = f_item.get("file_path", "")
		var content = f_item.get("content", "")
		var check = AISidebarPathPolicy.is_safe_to_write(raw_path)
		if not check["safe"]:
			return AISidebarToolResult.err("PERMISSION_DENIED", "Güvenlik engeli: " + check["reason"] + " (" + raw_path + ")")
		var p: String = check["path"]
		if rejected_raw.has(raw_path):
			rejected[p] = str(rejected_raw[raw_path])
			if first_code.is_empty():
				first_code = str(codes_raw.get(raw_path, "VALIDATION_FAILED"))
			if not FileAccess.file_exists(p):
				rejected_writes[p] = rejected[p]
			continue
		if errors_raw.has(raw_path):
			with_errors[p] = str(errors_raw[raw_path])
		files_to_write.append({
			"path": p,
			"content": content
		})

	if files_to_write.is_empty():
		if rejected.is_empty():
			return AISidebarToolResult.err("INVALID_ARGUMENT", "Yazılacak geçerli dosya bulunamadı.")
		var lines := PackedStringArray()
		for p: String in rejected.keys():
			lines.append("%s: %s" % [p, rejected[p]])
		return AISidebarToolResult.err(first_code, "WRITE_REJECTED: NO file was written. Files NOT written by this call: %s. Fix them and send the complete files again; do not patch them with replace_file_content." % "; ".join(lines), true, {
			"operation_status": "REJECTED", "disk_state": "UNCHANGED", "verification_status": "FAILED",
			"error_class": _error_class(first_code), "retry_strategy": "RESEND_FULL_FILE", "rejected_files": rejected,
		})
		
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
	for p: String in written_paths:
		_note_write(p, str(with_errors.get(p, "")))
	var data: Dictionary = res["data"]
	data["operation_status"] = "PARTIAL" if not rejected.is_empty() else "APPLIED"
	data["disk_state"] = "WRITTEN"
	data["verification_status"] = "PASSED" if rejected.is_empty() and with_errors.is_empty() else "FAILED"
	if not rejected.is_empty() or not with_errors.is_empty():
		var notes := PackedStringArray(["%d file(s) written: %s." % [written_paths.size(), ", ".join(PackedStringArray(written_paths))]])
		if not rejected.is_empty():
			data["rejected_files"] = rejected
			notes.append("REJECTED, NOT written (blocking error; send the complete fixed file again, do not patch): " + "; ".join(_pairs(rejected)))
		if not with_errors.is_empty():
			data["files_with_errors"] = with_errors
			notes.append("WRITTEN_WITH_ERRORS, on disk but not compiling (do not recreate; fix with replace_file_content or write the missing dependency): " + "; ".join(_pairs(with_errors)))
		data["message"] = " ".join(notes)
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

## Bütün proje (ya da bir klasör) gerçek bağlamda derlenir; hatalar dosya / satır / mesaj ile döner.
static func _validate_project(args: Dictionary) -> Dictionary:
	var root := str(args.get("path", "res://")).strip_edges()
	if root.is_empty():
		root = "res://"
	if not root.begins_with("res://") or ".." in root.split("/"):
		return AISidebarToolResult.err("INVALID_ARGUMENT", "path must be a folder inside the project (res://...).")
	if not DirAccess.dir_exists_absolute(root):
		return AISidebarToolResult.err("FILE_NOT_FOUND", "Folder not found: " + root)
	var report := AISidebarProjectValidator.run(root)
	var error_count: int = report["error_count"]
	if error_count > 0:
		return AISidebarToolResult.err("PROJECT_VALIDATION_FAILED", "%d error(s) in %s." % [error_count, root], true, report)
	return AISidebarToolResult.ok(report)

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
