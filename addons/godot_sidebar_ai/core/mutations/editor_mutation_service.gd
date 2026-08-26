@tool
extends RefCounted
class_name AISidebarMutationService

## Merkezi Editör Mutasyon ve Undo/Redo Servisi (SRP).

const AISidebarToolResult = preload("res://addons/godot_sidebar_ai/core/types/tool_result.gd")

static func get_undo_redo() -> EditorUndoRedoManager:
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_editor_undo_redo"):
		return EditorInterface.get_editor_undo_redo()
	return null

static func get_scene_root() -> Node:
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_edited_scene_root"):
		return EditorInterface.get_edited_scene_root()
	return null

# 1. Düğüm Ekleme (Undo/Redo)
static func add_node(parent: Node, new_node: Node, node_name: String) -> Dictionary:
	var root = get_scene_root()
	if not root or not parent or not new_node:
		return AISidebarToolResult.err("INVALID_STATE", "Geçersiz sahne veya düğüm.")
		
	new_node.name = node_name
	var ur = get_undo_redo()
	if ur:
		ur.create_action("AI: Add Node " + node_name)
		ur.add_do_method(parent, "add_child", new_node)
		ur.add_do_property(new_node, "owner", root)
		ur.add_do_reference(new_node)
		ur.add_undo_method(parent, "remove_child", new_node)
		ur.commit_action()
	else:
		parent.add_child(new_node)
		new_node.owner = root
		
	return AISidebarToolResult.ok({"path": str(new_node.get_path()), "name": new_node.name}, "Düğüm eklendi (UndoRedo kayıtlı).")

# 2. Düğüm Silme (Undo/Redo)
static func delete_node(target: Node) -> Dictionary:
	var root = get_scene_root()
	if not root or not target or target == root:
		return AISidebarToolResult.err("INVALID_TARGET", "Kök düğüm veya geçersiz düğüm silinemez.")
		
	var parent = target.get_parent()
	var node_name = target.name
	var ur = get_undo_redo()
	if ur:
		ur.create_action("AI: Delete Node " + node_name)
		ur.add_do_method(parent, "remove_child", target)
		ur.add_undo_method(parent, "add_child", target)
		ur.add_undo_property(target, "owner", root)
		ur.add_undo_reference(target)
		ur.commit_action()
	else:
		parent.remove_child(target)
		target.queue_free()
		
	return AISidebarToolResult.ok(null, "Düğüm silindi (UndoRedo kayıtlı): " + node_name)

# 3. Özellik Değiştirme (Undo/Redo)
static func set_property(target: Node, property_name: String, new_val: Variant) -> Dictionary:
	if not target:
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Hedef düğüm bulunamadı.")
		
	var old_val = target.get(property_name)
	var ur = get_undo_redo()
	if ur:
		ur.create_action("AI: Set Property " + property_name + " on " + target.name)
		ur.add_do_property(target, property_name, new_val)
		ur.add_undo_property(target, property_name, old_val)
		ur.commit_action()
	else:
		target.set(property_name, new_val)
		
	return AISidebarToolResult.ok({"node": str(target.get_path()), "property": property_name, "value": str(new_val)}, "Özellik güncellendi (UndoRedo kayıtlı).")

# 4. Sinyal Bağlama (Undo/Redo)
static func connect_signal(source: Node, signal_name: String, target: Node, method_name: String) -> Dictionary:
	if not source or not target:
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Kaynak veya hedef düğüm bulunamadı.")
		
	if not source.has_signal(signal_name):
		return AISidebarToolResult.err("SIGNAL_NOT_FOUND", "Kaynak düğümde bu sinyal yok: " + signal_name)
		
	var callable = Callable(target, method_name)
	var ur = get_undo_redo()
	if ur:
		ur.create_action("AI: Connect Signal " + signal_name + " -> " + method_name)
		ur.add_do_method(source, "connect", signal_name, callable)
		ur.add_undo_method(source, "disconnect", signal_name, callable)
		ur.commit_action()
	else:
		if not source.is_connected(signal_name, callable):
			source.connect(signal_name, callable)
			
	return AISidebarToolResult.ok(null, "Sinyal bağlandı (UndoRedo kayıtlı): " + signal_name + " -> " + method_name)

# 5. Script Bağlama (Undo/Redo)
static func attach_script(target: Node, script_res: Script) -> Dictionary:
	if not target or not script_res:
		return AISidebarToolResult.err("INVALID_PARAMS", "Düğüm veya script geçersiz.")
		
	var old_script = target.get_script()
	var ur = get_undo_redo()
	if ur:
		ur.create_action("AI: Attach Script to " + target.name)
		ur.add_do_method(target, "set_script", script_res)
		ur.add_undo_method(target, "set_script", old_script)
		ur.commit_action()
	else:
		target.set_script(script_res)
		
	return AISidebarToolResult.ok(null, "Script düğüme bağlandı (UndoRedo kayıtlı).")

# 6. Düğüm Yeniden Konumlandırma (Reparent - Undo/Redo)
static func reparent_node(target: Node, new_parent: Node) -> Dictionary:
	var root = get_scene_root()
	if not root or not target or not new_parent:
		return AISidebarToolResult.err("INVALID_STATE", "Geçersiz sahne veya düğüm.")
		
	var old_parent = target.get_parent()
	if old_parent == new_parent:
		return AISidebarToolResult.ok(null, "Düğüm zaten bu üst düğüme bağlı.")
		
	var ur = get_undo_redo()
	if ur:
		ur.create_action("AI: Reparent " + target.name + " to " + new_parent.name)
		ur.add_do_method(target, "reparent", new_parent)
		ur.add_do_property(target, "owner", root)
		ur.add_undo_method(target, "reparent", old_parent)
		ur.add_undo_property(target, "owner", root)
		ur.commit_action()
	else:
		target.reparent(new_parent)
		target.owner = root
		
	return AISidebarToolResult.ok(null, "Düğüm taşındı (UndoRedo kayıtlı): " + target.name + " -> " + new_parent.name)

# 7. Düğüm Yeniden Adlandırma (Rename - Undo/Redo)
static func rename_node(target: Node, new_name: String) -> Dictionary:
	if not target:
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm bulunamadı.")
		
	var old_name = target.name
	var ur = get_undo_redo()
	if ur:
		ur.create_action("AI: Rename " + old_name + " -> " + new_name)
		ur.add_do_property(target, "name", new_name)
		ur.add_undo_property(target, "name", old_name)
		ur.commit_action()
	else:
		target.name = new_name
		
	return AISidebarToolResult.ok({"old_name": old_name, "new_name": new_name}, "Düğüm yeniden adlandırıldı (UndoRedo kayıtlı).")

# 8. Düğüm Kopyalama (Duplicate - Undo/Redo)
static func duplicate_node(target: Node, new_name: String = "") -> Dictionary:
	var root = get_scene_root()
	if not root or not target:
		return AISidebarToolResult.err("INVALID_STATE", "Geçersiz sahne veya düğüm.")
		
	var parent = target.get_parent()
	var dup = target.duplicate()
	if not new_name.is_empty():
		dup.name = new_name
		
	return add_node(parent, dup, dup.name)
