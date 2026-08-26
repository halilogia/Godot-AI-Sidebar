@tool
extends RefCounted
class_name AISidebarPermissionPolicy

## Araç Yetki ve Güvenlik Seviyesi Yöneticisi (SRP).

enum PermissionLevel {
	READ_ONLY,     # Otomatik çalışır, sıfır risk (get_scene_tree, read_script, search_files)
	SAFE_MUTATION, # UndoRedo ile güvenli sahne/kod ekleme (add_node, set_property, create_script)
	DESTRUCTIVE    # Silme veya üzerine yazma işlemleri (delete_node, delete_file)
}

static func get_tool_permission_level(tool_name: String) -> PermissionLevel:
	match tool_name:
		"get_scene_tree", "read_script", "get_project_files", "get_selected_nodes", "get_node_properties", "get_editor_errors", "search_tools", "validate_script":
			return PermissionLevel.READ_ONLY
		"delete_node", "delete_file":
			return PermissionLevel.DESTRUCTIVE
		_:
			return PermissionLevel.SAFE_MUTATION
