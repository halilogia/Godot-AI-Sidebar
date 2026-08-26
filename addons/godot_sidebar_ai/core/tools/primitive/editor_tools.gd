@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarEditorTools

## İlkel Editör, Proje ve Çalışma Zamanı (Runtime Debugger) Araçları (SRP).

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarRuntimeDebugger = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_debugger.gd")

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
				"name": "search_project_assets",
				"description": "Projedeki sahneleri, scriptleri, dokuları, materyalleri veya ses dosyalarını türe göre arar.",
				"parameters": {
					"type": "object",
					"properties": {
						"query": { "type": "string", "description": "Aranacak dosya adı veya kelime (örn: 'player', 'jump', 'icon')." },
						"asset_type": { "type": "string", "description": "Asset tipi: 'scene', 'script', 'texture', 'material', 'audio', 'all'" }
					},
					"required": ["query"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "analyze_project",
				"description": "Projenin genel yapısını, ana sahnesini, sahne/script sayılarını ve mimarisini özetler.",
				"parameters": {
					"type": "object",
					"properties": {}
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
				"name": "select_node",
				"description": "Belirtilen düğümü Godot sahne ağacında ve Inspector panelinde seçili hale getirir.",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Seçilecek düğüm yolu." }
					},
					"required": ["node_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "open_scene",
				"description": "Belirtilen sahneyi (.tscn) Godot ana editöründe açar.",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": { "type": "string", "description": "Açılacak sahne yolu (örn: res://scenes/Main.tscn)." }
					},
					"required": ["scene_path"]
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
				"name": "restart_game",
				"description": "Oyunu durdurup yeniden başlatır (Restart).",
				"parameters": {
					"type": "object",
					"properties": {
						"current_scene_only": { "type": "boolean", "description": "True ise sadece açık olan sahneyi yeniden oynatır." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "get_runtime_errors",
				"description": "Çalışan oyundan veya log dosyasından en son hata ve exception kayıtlarını kaynak satırlarıyla çeker.",
				"parameters": {
					"type": "object",
					"properties": {}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "take_editor_screenshot",
				"description": "Godot editör arayüzünün anlık ekran görüntüsünü alır.",
				"parameters": {
					"type": "object",
					"properties": {
						"save_path": { "type": "string", "description": "Kaydedilecek yol (varsayılan: user://ai_editor_snapshot.png)." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "take_runtime_screenshot",
				"description": "Çalışmakta olan oyun penceresinin anlık ekran görüntüsünü alır.",
				"parameters": {
					"type": "object",
					"properties": {
						"save_path": { "type": "string", "description": "Kaydedilecek yol (varsayılan: user://ai_runtime_snapshot.png)." }
					}
				}
			}
		}
	]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"get_project_files":
			return _get_project_files(args)
		"search_project_assets":
			return _search_project_assets(args)
		"analyze_project":
			return _analyze_project(args)
		"get_selected_nodes":
			return _get_selected_nodes(args)
		"select_node":
			return _select_node(args)
		"open_scene":
			return _open_scene(args)
		"play_game":
			return _play_game(args)
		"stop_game":
			return _stop_game(args)
		"restart_game":
			return _restart_game(args)
		"get_runtime_errors":
			return _get_runtime_errors(args)
		"take_editor_screenshot":
			return _take_editor_screenshot(args)
		"take_runtime_screenshot":
			return _take_runtime_screenshot(args)
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

static func _search_project_assets(args: Dictionary) -> Dictionary:
	var query = args.get("query", "").to_lower()
	var a_type = args.get("asset_type", "all").to_lower()
	
	var ext_list: Array = []
	match a_type:
		"scene": ext_list = [".tscn"]
		"script": ext_list = [".gd"]
		"texture": ext_list = [".png", ".jpg", ".jpeg", ".svg", ".webp"]
		"material": ext_list = [".tres", ".material"]
		"audio": ext_list = [".wav", ".ogg", ".mp3"]
		_: ext_list = [".tscn", ".gd", ".png", ".jpg", ".tres", ".wav", ".ogg"]
		
	var all_files: Array = []
	_scan_dir_recursive("res://", "", all_files)
	
	var matches: Array = []
	for f in all_files:
		var f_lower = f.to_lower()
		var ext_match = false
		for ext in ext_list:
			if f_lower.ends_with(ext):
				ext_match = true
				break
		if ext_match and (query.is_empty() or query in f_lower.get_file()):
			matches.append(f)
			
	return AISidebarToolResult.ok({
		"query": query,
		"asset_type": a_type,
		"count": matches.size(),
		"assets": matches
	})

static func _analyze_project(args: Dictionary) -> Dictionary:
	var proj_name = ProjectSettings.get_setting("application/config/name", "Godot Project")
	var main_scene = ProjectSettings.get_setting("application/run/main_scene", "res://")
	
	var all_files: Array = []
	_scan_dir_recursive("res://", "", all_files)
	
	var scene_count = 0
	var script_count = 0
	var texture_count = 0
	
	for f in all_files:
		if f.ends_with(".tscn"): scene_count += 1
		elif f.ends_with(".gd"): script_count += 1
		elif f.ends_with(".png") or f.ends_with(".svg"): texture_count += 1
		
	return AISidebarToolResult.ok({
		"project_name": proj_name,
		"main_scene": main_scene,
		"total_files": all_files.size(),
		"scenes_count": scene_count,
		"scripts_count": script_count,
		"textures_count": texture_count
	}, "Proje genel yapısı başarıyla analiz edildi.")

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
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.ok({"selected_nodes": []})
		
	var selection = EditorInterface.get_selection() if EditorInterface.has_method("get_selection") else null
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

static func _select_node(args: Dictionary) -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface") or not EditorInterface.has_method("get_edited_scene_root"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Düğüm seçimi yalnızca editör GUI açıkken yapılabilir.")
		
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	if not root.has_node(node_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm bulunamadı: " + node_path)
		
	var target = root.get_node(node_path)
	var sel = EditorInterface.get_selection()
	if sel:
		sel.clear()
		sel.add_node(target)
		return AISidebarToolResult.ok({"node_path": node_path}, "Düğüm editörde seçildi: " + target.name)
		
	return AISidebarToolResult.err("SELECTION_FAILED", "Seçim yöneticisine erişilemedi.")

static func _open_scene(args: Dictionary) -> Dictionary:
	var path = AISidebarPathPolicy.normalize_path(args.get("scene_path", ""))
	if not FileAccess.file_exists(path):
		return AISidebarToolResult.err("FILE_NOT_FOUND", "Sahne dosyası bulunamadı: " + path)
		
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("open_scene_from_path"):
		EditorInterface.open_scene_from_path(path)
		return AISidebarToolResult.ok({"scene_path": path}, "Sahne editörde açıldı: " + path)
		
	return AISidebarToolResult.err("EDITOR_REQUIRED", "Sahne açma işlemi editör gerektirir.")

static func _play_game(args: Dictionary) -> Dictionary:
	var debugger = AISidebarRuntimeDebugger.new()
	return debugger.play(args.get("current_scene_only", false))

static func _stop_game(args: Dictionary) -> Dictionary:
	var debugger = AISidebarRuntimeDebugger.new()
	return debugger.stop()

static func _restart_game(args: Dictionary) -> Dictionary:
	var debugger = AISidebarRuntimeDebugger.new()
	return debugger.restart(args.get("current_scene_only", false))

static func _get_runtime_errors(args: Dictionary) -> Dictionary:
	var debugger = AISidebarRuntimeDebugger.new()
	var checkpoint_ms = int(args.get("checkpoint_msec", 1500))
	var obs = debugger.observe_runtime(checkpoint_ms)
	return AISidebarToolResult.ok(obs.to_dict(), obs.get_observation_verdict())

static func _take_editor_screenshot(args: Dictionary) -> Dictionary:
	var path = args.get("save_path", "user://ai_editor_snapshot.png")
	return AISidebarRuntimeDebugger.take_editor_screenshot(path)

static func _take_runtime_screenshot(args: Dictionary) -> Dictionary:
	var path = args.get("save_path", "user://ai_runtime_snapshot.png")
	return AISidebarRuntimeDebugger.take_runtime_screenshot(path)
