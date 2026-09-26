@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarEditorTools

## İlkel Editör, Proje ve Çalışma Zamanı (Runtime Debugger) Araçları (SRP).

const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")
const AISidebarRuntimeDebugger = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_debugger.gd")
const AISidebarDebuggerPlugin = preload("res://addons/godot_sidebar_ai/core/runtime/debugger_plugin.gd")

static func get_schemas() -> Array:
	return [
		{
			"type": "function",
			"function": {
				"name": "get_project_files",
				"description": "Lists the project's files and folders, optionally filtered by extension (.tscn, .gd, .png).",
				"parameters": {
					"type": "object",
					"properties": {
						"sub_path": { "type": "string", "description": "Sub folder to list (default: 'res://')." },
						"extension_filter": { "type": "string", "description": "Extension filter (e.g. '.gd', '.tscn', '.tres')." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "search_project_assets",
				"description": "Searches the project's scenes, scripts, textures, materials or audio files by type.",
				"parameters": {
					"type": "object",
					"properties": {
						"query": { "type": "string", "description": "File name or word to search for (e.g. 'player', 'jump', 'icon')." },
						"asset_type": { "type": "string", "description": "Asset type: 'scene', 'script', 'texture', 'material', 'audio', 'all'" }
					},
					"required": ["query"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "analyze_project",
				"description": "Summarizes the project: structure, main scene, scene/script counts and architecture.",
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
				"description": "Lists the nodes the user has currently selected in the Godot scene tree.",
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
				"description": "Selects the given node in the Godot scene tree and Inspector.",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Path of the node to select." }
					},
					"required": ["node_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "open_scene",
				"description": "Opens the given scene (.tscn) in the Godot editor.",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": { "type": "string", "description": "Path of the scene to open (e.g. res://scenes/Main.tscn)." }
					},
					"required": ["scene_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "play_game",
				"description": "Runs the project (main scene) or the active scene.",
				"parameters": {
					"type": "object",
					"properties": {
						"current_scene_only": { "type": "boolean", "description": "If true, runs only the scene open in the editor (F6)." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "stop_game",
				"description": "Stops the running game.",
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
				"description": "Stops and restarts the game.",
				"parameters": {
					"type": "object",
					"properties": {
						"current_scene_only": { "type": "boolean", "description": "If true, restarts only the scene open in the editor." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "get_runtime_errors",
				"description": "Reads the latest errors and exceptions of the running game from its log, with source lines. Wait a few seconds after play_game; an inconclusive result means nothing was logged yet.",
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
				"description": "Takes a screenshot of the Godot editor window.",
				"parameters": {
					"type": "object",
					"properties": {
						"save_path": { "type": "string", "description": "Where to save the image (default: user://ai_editor_snapshot.png)." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "take_runtime_screenshot",
				"description": "Takes a screenshot of the running GAME's own viewport for visual analysis. Fails if the game is not running.",
				"parameters": {
					"type": "object",
					"properties": {
						"save_path": { "type": "string", "description": "Where to save the image (default: user://ai_runtime_snapshot.png)." },
						"max_dimension": { "type": "integer", "description": "Maximum length of the longest side in pixels (default: 960)." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "take_viewport_screenshot",
				"description": "Takes a screenshot of the editor's active 2D or 3D scene viewport for visual analysis.",
				"parameters": {
					"type": "object",
					"properties": {
						"viewport_type": {
							"type": "string",
							"enum": ["auto", "2d", "3d", "editor"],
							"description": "Viewport to capture. 'auto': 2D or 3D from the active scene root, '2d': the 2D editor viewport, '3d': the 3D editor viewport, 'editor': the whole editor window (default: 'auto')."
						},
						"viewport_index": {
							"type": "integer",
							"description": "3D viewport index (0-3, default: 0)."
						},
						"save_path": {
							"type": "string",
							"description": "Where to save the image (default: 'user://ai_viewport_snapshot.png')."
						},
						"max_dimension": {
							"type": "integer",
							"description": "Maximum image width/height in pixels; scaled down to save tokens (default: 1280, 0 keeps the original size)."
						}
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "inspect_runtime_tree",
				"description": "Lists the live scene tree of the running game (remote scene tree). The game must be running (play_game).",
				"parameters": {
					"type": "object",
					"properties": {
						"path": { "type": "string", "description": "Node path to start from (empty: the root)." },
						"max_depth": { "type": "integer", "description": "Maximum hierarchy depth (default: 3)." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "inspect_runtime_node",
				"description": "Reads safe properties of a live node in the running game (name, type, position, rotation, scale, visible, process_mode).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Path of the node to query (e.g. 'Main/Player' or absolute '/root/Main/Player')." }
					},
					"required": ["node_path"]
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
		"take_viewport_screenshot":
			return _take_viewport_screenshot(args)
		"inspect_runtime_tree":
			return _inspect_runtime_tree_sync(args)
		"inspect_runtime_node":
			return _inspect_runtime_node_sync(args)
		_:
			return AISidebarToolResult.err("UNKNOWN_TOOL", "Bilinmeyen editör aracı: " + tool_name)

static func is_async_tool(tool_name: String) -> bool:
	return tool_name in ["inspect_runtime_tree", "inspect_runtime_node", "take_runtime_screenshot"]

static func execute_async(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"inspect_runtime_tree":
			return await _inspect_runtime_tree(args)
		"inspect_runtime_node":
			return await _inspect_runtime_node(args)
		"take_runtime_screenshot":
			return await _take_runtime_screenshot_async(args)
		_:
			return execute(tool_name, args)

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

## Ekran görüntüsü kayıt yolu: boşsa varsayılan, sonra PathPolicy yazma kontrolü.
## Dönen sözlük `is_safe_to_write` biçimindedir ({safe, path} / {safe, reason}).
static func resolve_screenshot_path(raw_path: Variant, default_path: String) -> Dictionary:
	var raw = str(raw_path).strip_edges() if raw_path != null else ""
	if raw.is_empty():
		raw = default_path
	return AISidebarPathPolicy.is_safe_to_write(raw)

static func _take_editor_screenshot(args: Dictionary) -> Dictionary:
	var path_check = resolve_screenshot_path(args.get("save_path", ""), "user://ai_editor_snapshot.png")
	if not path_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", path_check["reason"])
	return AISidebarRuntimeDebugger.take_editor_screenshot(path_check["path"])

static func _take_runtime_screenshot(args: Dictionary) -> Dictionary:
	return AISidebarToolResult.err(
		"ASYNC_REQUIRED",
		"take_runtime_screenshot aracı asenkron çalışır. Lütfen execute_async kullanın."
	)

## Çalışan OYUNUN viewport görüntüsü (RuntimeBridge -> base64 -> vision payload).
static func _take_runtime_screenshot_async(args: Dictionary) -> Dictionary:
	var path_check = resolve_screenshot_path(args.get("save_path", ""), "user://ai_runtime_snapshot.png")
	if not path_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", path_check["reason"])
	var path = path_check["path"]
	var max_dim = clampi(int(args.get("max_dimension", 960)), 64, 2048)

	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Çalışan oyun ekran görüntüsü için GUI gereklidir.")

	var is_playing = false
	if EditorInterface.has_method("is_playing_scene"):
		is_playing = EditorInterface.is_playing_scene()
	if not is_playing:
		return AISidebarToolResult.err(
			"GAME_NOT_RUNNING",
			"Oyun şu anda çalışmıyor. Çalışan oyunun görüntüsünü almak için önce oyunu başlatın (play_game veya F5)."
		)

	var dbg = AISidebarDebuggerPlugin.instance
	if not dbg or not dbg.has_active_session():
		return AISidebarToolResult.err(
			"DEBUGGER_NOT_CONNECTED",
			"Oyun çalışıyor ancak aktif bir hata ayıklayıcı (debugger) oturumu henüz bağlanmadı. Lütfen bir saniye sonra tekrar deneyin."
		)

	var resp = await dbg.query_with_ready_check("capture_viewport", [max_dim])
	if not resp.get("success", false):
		return AISidebarToolResult.err(
			resp.get("error", "CAPTURE_FAILED"),
			resp.get("message", "Çalışan oyun viewport görüntüsü alınamadı.")
		)

	var img = Image.new()
	var raw = Marshalls.base64_to_raw(str(resp.get("base64", "")))
	if img.load_png_from_buffer(raw) != OK:
		return AISidebarToolResult.err("DECODE_FAILED", "Oyun görüntüsü çözümlenemedi.")
	return AISidebarRuntimeDebugger.build_runtime_payload(path, img)

static func _take_viewport_screenshot(args: Dictionary) -> Dictionary:
	var path_check = resolve_screenshot_path(args.get("save_path", ""), "user://ai_viewport_snapshot.png")
	if not path_check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", path_check["reason"])
	var requested_type = args.get("viewport_type", "auto").to_lower()
	var vp_index = int(args.get("viewport_index", 0))
	var max_dim = int(args.get("max_dimension", 1280))

	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Viewport ekran görüntüsü için editör GUI gereklidir.")
		
	var vp_type_str = requested_type
	var target_vp: Viewport = null
	
	if requested_type == "auto":
		var root = EditorInterface.get_edited_scene_root() if EditorInterface.has_method("get_edited_scene_root") else null
		if root is Node3D:
			vp_type_str = "3d"
		elif root is Node2D or root is Control:
			vp_type_str = "2d"
		else:
			vp_type_str = "2d"
			
	if vp_type_str == "3d":
		if EditorInterface.has_method("get_editor_viewport_3d"):
			target_vp = EditorInterface.get_editor_viewport_3d(clampi(vp_index, 0, 3))
	elif vp_type_str == "2d":
		if EditorInterface.has_method("get_editor_viewport_2d"):
			target_vp = EditorInterface.get_editor_viewport_2d()
	elif vp_type_str == "editor":
		if EditorInterface.has_method("get_base_control"):
			var base = EditorInterface.get_base_control()
			if base: target_vp = base.get_viewport()
			
	if not target_vp:
		if EditorInterface.has_method("get_editor_viewport_2d"):
			target_vp = EditorInterface.get_editor_viewport_2d()
		elif EditorInterface.has_method("get_base_control"):
			var base = EditorInterface.get_base_control()
			if base: target_vp = base.get_viewport()
			
	if not target_vp:
		return AISidebarToolResult.err("VIEWPORT_NOT_FOUND", "Aktif editör viewport'u bulunamadı.")
		
	var tex = target_vp.get_texture()
	if not tex:
		return AISidebarToolResult.err("TEXTURE_EMPTY", "Viewport dokusu (texture) alınamadı.")
		
	var img = tex.get_image()
	if not img or img.is_empty():
		return AISidebarToolResult.err("IMAGE_EMPTY", "Viewport görüntüsü boş.")
		
	downscale_to_max(img, max_dim)

	var norm_path = path_check["path"]
	var err = img.save_png(norm_path)
	if err != OK:
		return AISidebarToolResult.err("SAVE_FAILED", "Ekran görüntüsü diske kaydedilemedi: " + norm_path)
		
	var buffer = img.save_png_to_buffer()
	var b64 = Marshalls.raw_to_base64(buffer)
	
	return AISidebarToolResult.ok({
		"path": norm_path,
		"viewport_type": vp_type_str,
		"width": img.get_width(),
		"height": img.get_height(),
		"base64": b64,
		"has_vision_data": true
	}, "✓ " + vp_type_str.to_upper() + " Viewport ekran görüntüsü alındı (" + str(img.get_width()) + "x" + str(img.get_height()) + ")")

## Token tasarrufu için ölçeklendirme: uzun kenar max_dim'i aşıyorsa oran korunarak
## küçültür (yerinde). max_dim <= 0 ise dokunmaz.
static func downscale_to_max(img: Image, max_dim: int) -> void:
	if max_dim > 0 and (img.get_width() > max_dim or img.get_height() > max_dim):
		var orig_w = img.get_width()
		var orig_h = img.get_height()
		var ratio = float(orig_w) / float(orig_h)
		var new_w = max_dim
		var new_h = max_dim
		if ratio >= 1.0:
			new_h = maxi(1, int(float(max_dim) / ratio))
		else:
			new_w = maxi(1, int(float(max_dim) * ratio))
		img.resize(new_w, new_h, Image.INTERPOLATE_BILINEAR)

static func _inspect_runtime_tree_sync(args: Dictionary) -> Dictionary:
	var is_playing = false
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("is_playing_scene"):
		is_playing = EditorInterface.is_playing_scene()
		
	if not is_playing:
		return AISidebarToolResult.err(
			"GAME_NOT_RUNNING",
			"Oyun şu anda çalışmıyor. Canlı sahne ağacını incelemek için önce oyunu başlatın (play_game veya F5)."
		)
		
	return AISidebarToolResult.err(
		"ASYNC_REQUIRED",
		"inspect_runtime_tree aracı asenkron çalışır. Lütfen execute_async kullanın."
	)

static func _inspect_runtime_node_sync(args: Dictionary) -> Dictionary:
	var node_path = args.get("node_path", "")
	if node_path.is_empty():
		return AISidebarToolResult.err("MISSING_ARGUMENT", "'node_path' parametresi zorunludur.")
		
	var is_playing = false
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("is_playing_scene"):
		is_playing = EditorInterface.is_playing_scene()
		
	if not is_playing:
		return AISidebarToolResult.err(
			"GAME_NOT_RUNNING",
			"Oyun şu anda çalışmıyor. Düğüm özelliklerini incelemek için önce oyunu başlatın (play_game veya F5)."
		)
		
	return AISidebarToolResult.err(
		"ASYNC_REQUIRED",
		"inspect_runtime_node aracı asenkron çalışır. Lütfen execute_async kullanın."
	)

static func _inspect_runtime_tree(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var max_depth = clampi(int(args.get("max_depth", 3)), 0, 8)
	
	var is_playing = false
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("is_playing_scene"):
		is_playing = EditorInterface.is_playing_scene()
		
	if not is_playing:
		return AISidebarToolResult.err(
			"GAME_NOT_RUNNING",
			"Oyun şu anda çalışmıyor. Canlı sahne ağacını incelemek için önce oyunu başlatın (play_game veya F5)."
		)
		
	var dbg = AISidebarDebuggerPlugin.instance
	if not dbg or not dbg.has_active_session():
		return AISidebarToolResult.err(
			"DEBUGGER_NOT_CONNECTED",
			"Oyun çalışıyor ancak aktif bir hata ayıklayıcı (debugger) oturumu henüz bağlanmadı. Lütfen bir saniye sonra tekrar deneyin."
		)
		
	var resp = await dbg.query_with_ready_check("inspect_tree", [path, max_depth])
	if not resp.get("success", false):
		return AISidebarToolResult.err(
			resp.get("error", "INSPECT_FAILED"),
			resp.get("message", "Çalışma zamanı sahne ağacı sorgulanamadı.")
		)
		
	return AISidebarToolResult.ok(resp.get("tree", {}), "✓ Canlı sahne ağacı başarıyla alındı.")

static func _inspect_runtime_node(args: Dictionary) -> Dictionary:
	var node_path = args.get("node_path", "")
	if node_path.is_empty():
		return AISidebarToolResult.err("MISSING_ARGUMENT", "'node_path' parametresi zorunludur.")
		
	var is_playing = false
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("is_playing_scene"):
		is_playing = EditorInterface.is_playing_scene()
		
	if not is_playing:
		return AISidebarToolResult.err(
			"GAME_NOT_RUNNING",
			"Oyun şu anda çalışmıyor. Düğüm özelliklerini incelemek için önce oyunu başlatın (play_game veya F5)."
		)
		
	var dbg = AISidebarDebuggerPlugin.instance
	if not dbg or not dbg.has_active_session():
		return AISidebarToolResult.err(
			"DEBUGGER_NOT_CONNECTED",
			"Oyun çalışıyor ancak aktif bir hata ayıklayıcı (debugger) oturumu henüz bağlanmadı."
		)
		
	var resp = await dbg.query_with_ready_check("inspect_node", [node_path])
	if not resp.get("success", false):
		return AISidebarToolResult.err(
			resp.get("error", "INSPECT_FAILED"),
			resp.get("message", "Düğüm özellikleri sorgulanamadı: " + node_path)
		)
		
	return AISidebarToolResult.ok(resp.get("node", {}), "✓ Düğüm özellikleri başarıyla alındı: " + node_path)
