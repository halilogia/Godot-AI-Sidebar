@tool
extends RefCounted
class_name AISidebarPermissionPolicy

## Araç Yetki ve Güvenlik Seviyesi Yöneticisi & Denetleyicisi (SRP).
## Araçları risk seviyelerine göre sınıflandırır ve yıkıcı işlemlerde onay zorunluluğu koyar.

enum PermissionLevel {
	READ_ONLY,     # Otomatik çalışır, sıfır risk (get_scene_tree, read_script, search_files)
	SAFE_MUTATION, # UndoRedo ile güvenli sahne/kod ekleme (add_node, set_property, create_script)
	DESTRUCTIVE    # Silme, ezme veya geri alınamaz işlemler (delete_node, delete_file)
}

static func get_tool_permission_level(tool_name: String) -> PermissionLevel:
	match tool_name:
		"get_scene_tree", "read_script", "get_project_files", "get_selected_nodes", "get_node_properties", "get_editor_errors", "search_tools", "validate_script", "take_viewport_screenshot":
			return PermissionLevel.READ_ONLY
		"delete_node", "delete_file":
			return PermissionLevel.DESTRUCTIVE
		_:
			return PermissionLevel.SAFE_MUTATION

## Bu aracın çalıştırılması için kullanıcıdan açık onay alınması gerekir mi?
static func requires_user_approval(tool_name: String, args: Dictionary = {}) -> bool:
	var level = get_tool_permission_level(tool_name)
	if level == PermissionLevel.DESTRUCTIVE:
		return true
		
	# Eğer bir dosya sıfırdan yazılmıyor da mevcut bir dosya eziliyorsa yıkıcıdır
	if tool_name == "create_or_update_script":
		var path = args.get("file_path", "")
		if not path.is_empty() and FileAccess.file_exists(path):
			# Mevcut dosyayı ezme işlemi onay gerektirir
			return true
			
	return false
