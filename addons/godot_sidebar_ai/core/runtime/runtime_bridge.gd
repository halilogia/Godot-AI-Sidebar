@tool
extends Node
class_name AISidebarRuntimeBridge

## Çalışma Zamanı Köprüsü (Runtime Bridge) (SRP).
## Editör ile çalışan oyun süreci arasındaki yerleşik EngineDebugger kanalı üzerinden
## güvenli ve semantik sahne ağacı (Remote Scene Tree) ve düğüm denetimini sağlar.

const CAPTURE_NAME: String = "godot_ai"
var _is_registered: bool = false

func _ready() -> void:
	_try_register_capture()

func _process(_delta: float) -> void:
	if not _is_registered:
		_try_register_capture()
	else:
		set_process(false)

func _try_register_capture() -> void:
	if not OS.has_feature("editor") and not OS.has_feature("debug"):
		set_process(false)
		return
	if EngineDebugger.is_active():
		if not EngineDebugger.has_capture(CAPTURE_NAME):
			EngineDebugger.register_message_capture(CAPTURE_NAME, _on_debugger_message)
		_is_registered = true
		set_process(false)

func _exit_tree() -> void:
	if EngineDebugger.is_active() and EngineDebugger.has_capture(CAPTURE_NAME):
		EngineDebugger.unregister_message_capture(CAPTURE_NAME)

func _on_debugger_message(message: String, data: Array) -> bool:
	if message == "godot_ai:inspect_tree":
		var req_id = data[0] if data.size() > 0 else ""
		var target_path = str(data[1]) if data.size() > 1 else ""
		var max_depth = int(data[2]) if data.size() > 2 else 3
		max_depth = clampi(max_depth, 0, 8)
		
		var root = get_tree().root
		var target: Node = resolve_node_path(root, target_path)
			
		if target == null:
			var err_res = {"success": false, "error": "NODE_NOT_FOUND", "message": "Düğüm bulunamadı: " + target_path}
			EngineDebugger.send_message("godot_ai:response", [req_id, err_res])
			return true
			
		var tree_dict = serialize_tree(target, max_depth)
		var ok_res = {"success": true, "tree": tree_dict}
		EngineDebugger.send_message("godot_ai:response", [req_id, ok_res])
		return true
		
	elif message == "godot_ai:inspect_node":
		var req_id = data[0] if data.size() > 0 else ""
		var target_path = str(data[1]) if data.size() > 1 else ""
		
		var root = get_tree().root
		var target: Node = resolve_node_path(root, target_path)
		
		if target == null:
			var err_res = {"success": false, "error": "NODE_NOT_FOUND", "message": "Düğüm bulunamadı: " + target_path}
			EngineDebugger.send_message("godot_ai:response", [req_id, err_res])
			return true
			
		var node_dict = serialize_node(target)
		var ok_res = {"success": true, "node": node_dict}
		EngineDebugger.send_message("godot_ai:response", [req_id, ok_res])
		return true
		
	return false

## Node path'i hem relative ('Main/Player') hem mutlak ('/root/Main/Player') formatları normalize ederek çözer
static func resolve_node_path(root: Node, path_str: String) -> Node:
	if not root:
		return null
	var clean = path_str.strip_edges()
	if clean.is_empty() or clean == "/" or clean == "/root" or clean == "root":
		return root
	if clean.begins_with("/root/"):
		clean = clean.trim_prefix("/root/")
	elif clean.begins_with("root/"):
		clean = clean.trim_prefix("root/")
	elif clean.begins_with("/"):
		clean = clean.trim_prefix("/")
		
	return root.get_node_or_null(clean)

## Ağaç yapısını hiyerarşik ve derinlik limitli olarak serileştirir
static func serialize_tree(node: Node, max_depth: int = 3, current_depth: int = 0) -> Dictionary:
	if not node:
		return {}
	var node_path = str(node.get_path()) if node.is_inside_tree() else str(node.name)
	var info: Dictionary = {
		"name": str(node.name),
		"type": node.get_class(),
		"path": node_path,
		"child_count": node.get_child_count()
	}
	var script = node.get_script()
	if script and script is Script and not script.resource_path.is_empty():
		info["script"] = script.resource_path
		
	if current_depth < max_depth:
		var children: Array = []
		for child in node.get_children():
			children.append(serialize_tree(child, max_depth, current_depth + 1))
		info["children"] = children
		
	return info

## Güvenli whitelist alanlarıyla düğüm özelliklerini serileştirir
static func serialize_node(node: Node) -> Dictionary:
	if not node:
		return {}
		
	var node_path = str(node.get_path()) if node.is_inside_tree() else str(node.name)
	var info: Dictionary = {
		"name": str(node.name),
		"type": node.get_class(),
		"path": node_path,
		"process_mode": node.process_mode,
		"child_count": node.get_child_count()
	}
	
	if not node.scene_file_path.is_empty():
		info["scene_file_path"] = node.scene_file_path
		
	var script = node.get_script()
	if script and script is Script and not script.resource_path.is_empty():
		info["script"] = script.resource_path
		
	# Güvenli görsel ve uzamsal özellikler
	if "visible" in node:
		info["visible"] = node.get("visible")
		
	if "position" in node:
		var pos = node.get("position")
		if pos is Vector2:
			info["position"] = {"x": snapped(pos.x, 0.01), "y": snapped(pos.y, 0.01)}
		elif pos is Vector3:
			info["position"] = {"x": snapped(pos.x, 0.01), "y": snapped(pos.y, 0.01), "z": snapped(pos.z, 0.01)}
			
	if "rotation" in node:
		var rot = node.get("rotation")
		if rot is float:
			info["rotation"] = snapped(rot, 0.01)
		elif rot is Vector3:
			info["rotation"] = {"x": snapped(rot.x, 0.01), "y": snapped(rot.y, 0.01), "z": snapped(rot.z, 0.01)}
			
	if "scale" in node:
		var sc = node.get("scale")
		if sc is Vector2:
			info["scale"] = {"x": snapped(sc.x, 0.01), "y": snapped(sc.y, 0.01)}
		elif sc is Vector3:
			info["scale"] = {"x": snapped(sc.x, 0.01), "y": snapped(sc.y, 0.01), "z": snapped(sc.z, 0.01)}
			
	return info
