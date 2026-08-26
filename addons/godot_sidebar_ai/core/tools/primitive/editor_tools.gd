@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarEditorTools

## İlkel Editör ve Proje Dosya Sistemi Araçları (Primitive Tools) (SRP).

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")

static func get_schemas() -> Array:
	return [
		{
			"type": "function",
			"function": {
				"name": "get_project_files",
				"description": "Projedeki tüm dosya ve klasör ağacını veya belirli bir uzantıyı (.tscn, .gd, .png) listeler.",
				"parameters": {
					"type": "object",
					"properties": {
						"sub_path": { "type": "string", "description": "Taranacak alt dizin (varsayılan: 'res://')." },
						"extension_filter": { "type": "string", "description": "Filtre (örn: '.gd', '.tscn', '.tres')." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "get_selected_nodes",
				"description": "Kullanıcının Godot sahne ağacında şu anda fareyle seçtiği düğümleri listeler.",
				"parameters": {
					"type": "object",
					"properties": {}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "play_game",
				"description": "Projeyi veya aktif sahneyi test etmek için çalıştırır (Play).",
				"parameters": {
					"type": "object",
					"properties": {
						"current_scene_only": { "type": "boolean", "description": "True ise sadece açık olan sahneyi oynatır (F6)." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "stop_game",
				"description": "Çalışmakta olan oyunu durdurur (Stop).",
				"parameters": {
					"type": "object",
					"properties": {}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "get_editor_errors",
				"description": "Son derleme ve çalışma zamanı hata loglarını getirir.",
				"parameters": {
					"type": "object",
					"properties": {}
				}
			}
		}
	]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"get_project_files":
			return _get_project_files(args)
		"get_selected_nodes":
			return _get_selected_nodes(args)
		"play_game":
			return _play_game(args)
		"stop_game":
			return _stop_game(args)
		"get_editor_errors":
			return _get_editor_errors(args)
		_:
			return AISidebarToolResult.err("UNKNOWN_TOOL", "Bilinmeyen editör aracı: " + tool_name)

static func _get_project_files(args: Dictionary) -> Dictionary:
	var sub_path = AISidebarPathPolicy.normalize_path(args.get("sub_path", "res://"))
	var filter = args.get("extension_filter", "").to_lower()
	
	var files: Array = []
	_scan_dir_recursive(sub_path, filter, files)
	return AISidebarToolResult.ok({
		"path": sub_path,
		"count": files.size(),
		"files": files
	})

static func _scan_dir_recursive(path: String, filter: String, result: Array) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var item = dir.get_next()
	while not item.is_empty():
		if item != "." and item != ".." and not item.begins_with("."):
			var full_path = path.path_join(item)
			if dir.current_is_dir():
				if not full_path.begins_with("res://.git") and not full_path.begins_with("res://addons/godot_sidebar_ai"):
					_scan_dir_recursive(full_path, filter, result)
			else:
				if filter.is_empty() or item.to_lower().ends_with(filter):
					result.append(full_path)
		item = dir.get_next()
	dir.list_dir_end()

static func _get_selected_nodes(args: Dictionary) -> Dictionary:
	var selection = EditorInterface.get_selection()
	if not selection:
		return AISidebarToolResult.ok({"selected_nodes": []})
		
	var selected_array: Array = []
	for node in selection.get_selected_nodes():
		selected_array.append({
			"name": node.name,
			"path": str(node.get_path()),
			"type": node.get_class()
		})
	return AISidebarToolResult.ok({"selected_nodes": selected_array})

static func _play_game(args: Dictionary) -> Dictionary:
	var current_only = args.get("current_scene_only", false)
	if current_only:
		EditorInterface.play_current_scene()
		return AISidebarToolResult.ok(null, "Aktif sahne test için başlatıldı.")
	else:
		EditorInterface.play_main_scene()
		return AISidebarToolResult.ok(null, "Ana oyun başlatıldı.")

static func _stop_game(args: Dictionary) -> Dictionary:
	EditorInterface.stop_playing_scene()
	return AISidebarToolResult.ok(null, "Oyun durduruldu.")

static func _get_editor_errors(args: Dictionary) -> Dictionary:
	var log_path = OS.get_user_data_dir().path_join("logs/godot.log")
	if FileAccess.file_exists(log_path):
		var f = FileAccess.open(log_path, FileAccess.READ)
		if f:
			var txt = f.get_as_text()
			f.close()
			var lines = txt.split("\n")
			var error_lines: Array = []
			for l in lines:
				if "ERROR" in l or "SCRIPT ERROR" in l or "WARNING" in l:
					error_lines.append(l)
			return AISidebarToolResult.ok({"recent_errors": error_lines.slice(-20)})
			
	return AISidebarToolResult.ok({"recent_errors": []}, "Kayıtlı hata bulunamadı.")
