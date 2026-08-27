@tool
extends RefCounted
class_name AISidebarToolManager

## Merkezi Araç Yöneticisi, Yetki Denetleyicisi ve Progressive Tool Routing Motoru (SRP).
## 37 aracın tamamını her LLM isteğinde göndermek yerine, kullanıcı isteğine göre
## dinamik olarak yalnızca ilgili araç alt kümesini modele sunar.

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarSceneTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/scene_tools.gd")
const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")
const AISidebarEditorTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/editor_tools.gd")
const AISidebarGameIntentTools = preload("res://addons/godot_sidebar_ai/core/tools/intent/game_intent_tools.gd")

## Tüm mevcut araç şemalarını döner (Full Schema Catalog)
static func get_all_schemas() -> Array:
	var schemas: Array = []
	
	# Progressive Discovery: search_tools aracı
	schemas.append({
		"type": "function",
		"function": {
			"name": "search_tools",
			"description": "Mevcut tüm Godot araçları arasında arama yapar ve sadece ilgili araçların listesini döner.",
			"parameters": {
				"type": "object",
				"properties": {
					"query": { "type": "string", "description": "Aranacak kelime (örn: 'scene', 'script', 'camera', 'character', 'enemy', 'hud')." }
				},
				"required": ["query"]
			}
		}
	})
	
	schemas.append_array(AISidebarSceneTools.get_schemas())
	schemas.append_array(AISidebarScriptTools.get_schemas())
	schemas.append_array(AISidebarEditorTools.get_schemas())
	schemas.append_array(AISidebarGameIntentTools.get_schemas())
	
	return schemas

## Kullanıcı isteği veya konuşma bağlamına göre yalnızca ilgili araç şemalarını filtreler
static func get_relevant_schemas(context_text: String, explicitly_unlocked: Array = []) -> Array:
	var all_schemas = get_all_schemas()
	var text = context_text.to_lower()
	
	var active_tool_names: Dictionary = {}
	
	# 1. Çekirdek Araçlar (Core Discovery & Inspection - Daima Erişilebilir)
	var core_tools = ["search_tools", "analyze_project", "read_script"]
	for ct in core_tools:
		active_tool_names[ct] = true
		
	# 2. Kategori Anahtar Kelimeleri & Niyet Ayrımı
	var vision_keywords = [
		"viewport", "gör", "bak", "görüntü", "resim", "screenshot", "ekran", "vision",
		"görsel", "hiza", "align", "gözlem", "bakış", "incele"
	]
	var has_vision_intent = false
	for kw in vision_keywords:
		if kw in text:
			has_vision_intent = true
			break

	var runtime_keywords = [
		"runtime", "error", "hata", "bug", "crash", "play", "oyna", "çalıştır",
		"run", "test", "debug", "düzelt", "fix", "heal", "screenshot", "ekran",
		"stop", "durdur", "restart", "sıfırla", "log", "diagnostic", "check"
	]
	var has_runtime_intent = false
	for kw in runtime_keywords:
		if kw in text:
			has_runtime_intent = true
			break

	var script_keywords = [
		"script", "gdscript", "kod", "code", "fonksiyon", "method", "variable",
		"değişken", "class", "extends", "dosya", "file", "sil", "delete", "oluştur",
		"create", "yaz", "write", "düzenle", "edit", "güncelle", "update", "temizle",
		"validate", "doğrula", ".gd", "shader"
	]
	var has_script_intent = false
	for kw in script_keywords:
		if kw in text:
			has_script_intent = true
			break
			
	var scene_keywords = [
		"scene", "sahne", "node", "düğüm", "3d", "2d", "camera", "kamera",
		"hud", "ui", "arayüz", "level", "tscn", ".tscn", "mesh", "collision",
		"spawn", "rigid", "area", "light", "ışık", "spatial", "tree", "ağaç",
		"property", "özellik", "signal", "sinyal", "reparent", "select", "seç",
		"düşman sahnesi", "karakter sahnesi", "chest", "sandık"
	]
	var has_scene_intent = false
	for kw in scene_keywords:
		if kw in text:
			has_scene_intent = true
			break
			
	# 3. İlgili Kategorileri Aktif Et
	if has_vision_intent:
		var vision_tools = [
			"take_viewport_screenshot", "take_editor_screenshot", "take_runtime_screenshot",
			"get_active_scene_tree", "get_selected_nodes", "replace_file_content"
		]
		for vt in vision_tools:
			active_tool_names[vt] = true

	if has_runtime_intent:
		# Runtime / Debug odaklı dar araç seti (~10 araç)
		var runtime_tools = [
			"play_game", "stop_game", "restart_game", "get_runtime_errors",
			"take_runtime_screenshot", "take_viewport_screenshot", "create_or_update_script", "replace_file_content", "validate_script", "read_script"
		]
		for rt in runtime_tools:
			active_tool_names[rt] = true
			
	if has_script_intent:
		var script_tools = [
			"create_or_update_script", "replace_file_content", "validate_script", "write_files",
			"delete_file", "list_dir", "get_open_scripts", "read_script"
		]
		for st in script_tools:
			active_tool_names[st] = true
			
	if has_scene_intent:
		var scene_tools = [
			"create_scene", "save_scene", "add_node", "delete_node", "rename_node",
			"duplicate_node", "set_node_property", "connect_signal", "reparent_node",
			"select_node", "get_active_scene_tree", "get_selected_nodes", "write_files",
			"list_dir", "take_viewport_screenshot", "create_character_scene", "create_enemy_scene",
			"create_ui_hud", "create_interactable", "setup_camera_follow"
		]
		for sc in scene_tools:
			active_tool_names[sc] = true
			
	# 4. Hiçbir kategori eşleşmediyse varsayılan temel araç kümesini sun
	if not has_script_intent and not has_scene_intent and not has_runtime_intent and not has_vision_intent:
		var default_tools = [
			"create_or_update_script", "replace_file_content", "create_scene", "save_scene",
			"play_game", "get_runtime_errors", "take_viewport_screenshot", "write_files", "list_dir", "read_script"
		]
		for dt in default_tools:
			active_tool_names[dt] = true
			
	# 5. search_tools veya önceki adımlarda açılan özel araçlar (Progressive Unlocking)
	for ut in explicitly_unlocked:
		var ut_str = str(ut)
		if not ut_str.is_empty():
			active_tool_names[ut_str] = true
			
	# 6. Sıralı Şema Çıktısı Oluştur
	var filtered_schemas: Array = []
	for s in all_schemas:
		var fn_name = s.get("function", {}).get("name", "")
		if active_tool_names.has(fn_name):
			filtered_schemas.append(s)
			
	return filtered_schemas

static func execute_tool(tool_name: String, args: Dictionary, is_user_approved: bool = false) -> Dictionary:
	if tool_name == "search_tools":
		return _search_tools(args)
		
	# 1. Gerçek Yetki Denetimi (Permission Enforcement)
	if not is_user_approved and AISidebarPermissionPolicy.requires_user_approval(tool_name, args):
		return AISidebarToolResult.err(
			"APPROVAL_REQUIRED",
			"Bu işlem (" + tool_name + ") kullanıcı onayı gerektirir.",
			true,
			{"requires_approval": true, "tool_name": tool_name, "args": args}
		)
		
	# 2. Sahne İlkel Araçları
	for s in AISidebarSceneTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarSceneTools.execute(tool_name, args)
			
	# 3. Script İlkel Araçları
	for s in AISidebarScriptTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarScriptTools.execute(tool_name, args)
			
	# 4. Editör İlkel Araçları
	for s in AISidebarEditorTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarEditorTools.execute(tool_name, args)
			
	# 5. Yüksek Seviyeli Intent Araçları
	for s in AISidebarGameIntentTools.get_schemas():
		if s["function"]["name"] == tool_name:
			return AISidebarGameIntentTools.execute(tool_name, args)
			
	return AISidebarToolResult.err("UNKNOWN_TOOL", "Bilinmeyen motor aracı: " + tool_name)

static func _search_tools(args: Dictionary) -> Dictionary:
	var query = str(args.get("query", "")).to_lower()
	var all = get_all_schemas()
	var matches: Array = []
	
	for tool_def in all:
		var fn = tool_def.get("function", {})
		var t_name = fn.get("name", "")
		var t_desc = fn.get("description", "")
		if query.is_empty() or query in t_name.to_lower() or query in t_desc.to_lower():
			matches.append({
				"name": t_name,
				"description": t_desc
			})
			
	return AISidebarToolResult.ok({
		"query": query,
		"count": matches.size(),
		"tools": matches
	})
