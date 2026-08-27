@tool
extends RefCounted
class_name AISidebarPermissionPolicy

## Araç Yetki ve Güvenlik Seviyesi Yöneticisi & Denetleyicisi (SRP).

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

enum PermissionLevel {
	READ_ONLY,     # Otomatik çalışır, sıfır risk (get_scene_tree, read_script, search_assets)
	SAFE_MUTATION, # UndoRedo ile güvenli sahne/kod ekleme (add_node, set_property, create_script)
	DESTRUCTIVE    # Silme veya ezme işlemleri (delete_node, delete_file, overwrite_script)
}

static func get_tool_permission_level(tool_name: String) -> PermissionLevel:
	match tool_name:
		"get_scene_tree", "read_script", "get_project_files", "search_project_assets", "get_selected_nodes", "get_node_properties", "get_editor_errors", "search_tools", "validate_script", "take_editor_screenshot", "take_runtime_screenshot", "take_viewport_screenshot", "analyze_project":
			return PermissionLevel.READ_ONLY
		"delete_node", "delete_file":
			return PermissionLevel.DESTRUCTIVE
		_:
			return PermissionLevel.SAFE_MUTATION

## Bu aracın çalıştırılması için kullanıcıdan açık onay alınması gerekir mi?
static func requires_user_approval(tool_name: String, args: Dictionary = {}) -> bool:
	var cfg = AISidebarConfig.load_config()
	var level = get_tool_permission_level(tool_name)
	
	if level == PermissionLevel.DESTRUCTIVE:
		var req_delete = cfg.get("require_delete_approval", true)
		if not req_delete and tool_name in ["delete_node", "delete_file"]:
			return false
		return true
		
	# Eğer bir dosya sıfırdan yazılmıyor da mevcut bir dosya eziliyorsa veya cerrahi değiştiriliyorsa
	if tool_name in ["create_or_update_script", "replace_file_content"]:
		var path = args.get("file_path", "")
		if not path.is_empty() and FileAccess.file_exists(path):
			var req_overwrite = cfg.get("require_overwrite_approval", true)
			return req_overwrite
			
	return false
