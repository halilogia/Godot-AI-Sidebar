@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarSceneTools

## İlkel Sahne ve Düğüm (Node) Araçları (Primitive Tools) (SRP).

const AISidebarTypeParser = preload("res://addons/godot_sidebar_ai/core/types/type_parser.gd")
const AISidebarMutationService = preload("res://addons/godot_sidebar_ai/core/mutations/editor_mutation_service.gd")
const AISidebarPathPolicy = preload("res://addons/godot_sidebar_ai/core/security/path_policy.gd")

static func _get_root() -> Node:
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("get_edited_scene_root"):
		return EditorInterface.get_edited_scene_root()
	return null

static func get_schemas() -> Array:
	return [
		{
			"type": "function",
			"function": {
				"name": "get_scene_tree",
				"description": "Aktif sahnedeki tüm düğüm (node) hiyerarşisini, tiplerini ve yollarını listeler.",
				"parameters": {
					"type": "object",
					"properties": {
						"root_path": { "type": "string", "description": "Taranacak başlangıç düğüm yolu (varsayılan: aktif sahne kökü)." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "add_node",
				"description": "Sahneye yeni bir düğüm (Node2D, CharacterBody2D, Camera2D, Button vb.) ekler (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_type": { "type": "string", "description": "Godot sınıf adı (Örn: CharacterBody2D, Sprite2D, Node3D, Label)." },
						"node_name": { "type": "string", "description": "Düğümün adı (Örn: Player, HealthBar, Background)." },
						"parent_path": { "type": "string", "description": "Ekleneceği üst düğümün yolu (boşsa sahne köküne eklenir)." }
					},
					"required": ["node_type", "node_name"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "delete_node",
				"description": "Sahnede belirtilen düğümü siler (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Silinecek düğümün tam veya göreli yolu." }
					},
					"required": ["node_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "set_node_property",
				"description": "Bir düğümün özelliğini (position, scale, text vb.) değiştirir (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Hedef düğümün yolu." },
						"property_name": { "type": "string", "description": "Değiştirilecek özellik adı." },
						"property_value": { "description": "Yeni değer ('Vector2(100, 200)', '#ff0000', sayı vb.)." }
					},
					"required": ["node_path", "property_name", "property_value"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "get_node_properties",
				"description": "Bir düğümün tüm inspector özelliklerini ve mevcut değerlerini listeler.",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "İncelenecek düğüm yolu." }
					},
					"required": ["node_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "connect_signal",
				"description": "İki düğüm arasındaki bir sinyali hedefin metoduna bağlar (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"source_node_path": { "type": "string", "description": "Sinyali yayınlayan düğüm yolu." },
						"signal_name": { "type": "string", "description": "Sinyal adı (örn: pressed, body_entered)." },
						"target_node_path": { "type": "string", "description": "Sinyali dinleyen düğüm yolu." },
						"method_name": { "type": "string", "description": "Çalıştırılacak fonksiyon adı." }
					},
					"required": ["source_node_path", "signal_name", "target_node_path", "method_name"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "attach_script_to_node",
				"description": "Diskteki bir GDScript dosyasını aktif sahnedeki belirli bir düğüme bağlar (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Hedef düğümün yolu." },
						"script_path": { "type": "string", "description": "Script yolu (örn: res://scripts/Player.gd)." }
					},
					"required": ["node_path", "script_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "reparent_node",
				"description": "Bir düğümü başka bir üst düğümün altına taşır (Ctrl+Z ile geri alınabilir).",
				"parameters": {
					"type": "object",
					"properties": {
						"node_path": { "type": "string", "description": "Taşınacak düğümün yolu." },
						"new_parent_path": { "type": "string", "description": "Yeni üst düğümün yolu." }
					},
					"required": ["node_path", "new_parent_path"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "create_scene",
				"description": "Sıfırdan yeni bir sahne (.tscn) dosyası oluşturur.",
				"parameters": {
					"type": "object",
					"properties": {
						"scene_path": { "type": "string", "description": "Kaydedilecek yol (örn: res://scenes/Level1.tscn)." },
						"root_type": { "type": "string", "description": "Kök düğüm tipi (örn: Node2D, Control, Node3D)." },
						"root_name": { "type": "string", "description": "Kök düğüm adı (örn: Level1, MainMenu)." }
					},
					"required": ["scene_path", "root_type"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "save_scene",
				"description": "Aktif olarak düzenlenen sahneyi diske kaydeder.",
				"parameters": {
					"type": "object",
					"properties": {}
				}
			}
		}
	]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"get_scene_tree":
			return _get_scene_tree(args)
		"add_node":
			return _add_node(args)
		"delete_node":
			return _delete_node(args)
		"set_node_property":
			return _set_node_property(args)
		"get_node_properties":
			return _get_node_properties(args)
		"connect_signal":
			return _connect_signal(args)
		"attach_script_to_node":
			return _attach_script_to_node(args)
		"reparent_node":
			return _reparent_node(args)
		"create_scene":
			return _create_scene(args)
		"save_scene":
			return _save_scene(args)
		_:
			return AISidebarToolResult.err("UNKNOWN_TOOL", "Bilinmeyen sahne aracı: " + tool_name)

static func _get_scene_tree(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var start_node = root
	var root_path = args.get("root_path", "")
	if not root_path.is_empty() and root.has_node(root_path):
		start_node = root.get_node(root_path)
		
	var tree_data = _build_node_dict(start_node)
	return AISidebarToolResult.ok({
		"scene_root": root.name,
		"scene_file": root.scene_file_path,
		"tree": tree_data
	})

static func _build_node_dict(node: Node) -> Dictionary:
	var children: Array = []
	for child in node.get_children():
		children.append(_build_node_dict(child))
	return {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"children": children
	}

static func _add_node(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_type = args.get("node_type", "")
	var node_name = args.get("node_name", "")
	var parent_path = args.get("parent_path", "")
	
	if not ClassDB.class_exists(node_type):
		return AISidebarToolResult.err("INVALID_CLASS", "Geçersiz Godot sınıfı: " + node_type)
		
	var parent: Node = root
	if not parent_path.is_empty():
		if root.has_node(parent_path):
			parent = root.get_node(parent_path)
		else:
			return AISidebarToolResult.err("PARENT_NOT_FOUND", "Üst düğüm bulunamadı: " + parent_path)
			
	var new_node = ClassDB.instantiate(node_type)
	if not new_node:
		return AISidebarToolResult.err("INSTANTIATION_FAILED", "Düğüm oluşturulamadı: " + node_type)
		
	return AISidebarMutationService.add_node(parent, new_node, node_name)

static func _delete_node(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	if not root.has_node(node_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm bulunamadı: " + node_path)
		
	var target = root.get_node(node_path)
	return AISidebarMutationService.delete_node(target)

static func _set_node_property(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	var prop_name = args.get("property_name", "")
	var raw_val = args.get("property_value")
	
	if not root.has_node(node_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm bulunamadı: " + node_path)
		
	var target = root.get_node(node_path)
	var final_val = AISidebarTypeParser.parse_smart_variant(raw_val)
	return AISidebarMutationService.set_property(target, prop_name, final_val)

static func _get_node_properties(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	if not root.has_node(node_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm bulunamadı: " + node_path)
		
	var target = root.get_node(node_path)
	var prop_list: Dictionary = {}
	for p in target.get_property_list():
		var p_name = p["name"]
		if not p_name.begins_with("_"):
			prop_list[p_name] = str(target.get(p_name))
			
	return AISidebarToolResult.ok({
		"node": node_path,
		"type": target.get_class(),
		"properties": prop_list
	})

static func _connect_signal(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var src_path = args.get("source_node_path", "")
	var sig_name = args.get("signal_name", "")
	var tgt_path = args.get("target_node_path", "")
	var meth_name = args.get("method_name", "")
	
	if not root.has_node(src_path) or not root.has_node(tgt_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Kaynak veya hedef düğüm bulunamadı.")
		
	var src_node = root.get_node(src_path)
	var tgt_node = root.get_node(tgt_path)
	return AISidebarMutationService.connect_signal(src_node, sig_name, tgt_node, meth_name)

static func _attach_script_to_node(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	var script_path = AISidebarPathPolicy.normalize_path(args.get("script_path", ""))
	
	if not root.has_node(node_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm bulunamadı: " + node_path)
	if not FileAccess.file_exists(script_path):
		return AISidebarToolResult.err("FILE_NOT_FOUND", "Script dosyası bulunamadı: " + script_path)
		
	var target = root.get_node(node_path)
	var script_res = load(script_path)
	if not script_res:
		return AISidebarToolResult.err("LOAD_FAILED", "Script yüklenemedi: " + script_path)
		
	return AISidebarMutationService.attach_script(target, script_res)

static func _reparent_node(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var node_path = args.get("node_path", "")
	var new_parent_path = args.get("new_parent_path", "")
	
	if not root.has_node(node_path) or not root.has_node(new_parent_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Düğüm veya yeni üst düğüm bulunamadı.")
		
	var target = root.get_node(node_path)
	var new_parent = root.get_node(new_parent_path)
	return AISidebarMutationService.reparent_node(target, new_parent)

static func _create_scene(args: Dictionary) -> Dictionary:
	var raw_path = args.get("scene_path", "")
	var scene_path = AISidebarPathPolicy.normalize_path(raw_path)
	var root_type = args.get("root_type", "Node2D")
	var root_name = args.get("root_name", "Root")
	
	var check = AISidebarPathPolicy.is_safe_to_write(scene_path)
	if not check["safe"]:
		return AISidebarToolResult.err("PERMISSION_DENIED", check["reason"])
		
	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"
		
	if not ClassDB.class_exists(root_type):
		return AISidebarToolResult.err("INVALID_CLASS", "Geçersiz kök düğüm tipi: " + root_type)
		
	var root_node = ClassDB.instantiate(root_type)
	root_node.name = root_name
	
	var packed_scene = PackedScene.new()
	var pack_err = packed_scene.pack(root_node)
	if pack_err != OK:
		return AISidebarToolResult.err("PACK_FAILED", "Sahne paketlenemedi: " + str(pack_err))
		
	var save_err = ResourceSaver.save(packed_scene, scene_path)
	if save_err != OK:
		return AISidebarToolResult.err("SAVE_FAILED", "Sahne kaydedilemedi: " + str(save_err))
		
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
		if EditorInterface.has_method("get_resource_filesystem"):
			EditorInterface.get_resource_filesystem().scan()
		if EditorInterface.has_method("open_scene_from_path"):
			EditorInterface.open_scene_from_path(scene_path)
			
	return AISidebarToolResult.ok({"scene_path": scene_path}, "Sahne oluşturuldu ve editörde açıldı.")

static func _save_scene(args: Dictionary) -> Dictionary:
	var root = _get_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Kaydedilecek aktif sahne yok.")
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface") and EditorInterface.has_method("save_scene"):
		EditorInterface.save_scene()
	return AISidebarToolResult.ok({"scene_file": root.scene_file_path}, "Aktif sahne kaydedildi.")
