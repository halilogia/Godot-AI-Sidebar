@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarGameIntentTools

## Yüksek Seviyeli Oyun Üretim Araçları (Intent-Based Tools) (SRP).

const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")

static func get_schemas() -> Array:
	return [
		{
			"type": "function",
			"function": {
				"name": "create_character_scene",
				"description": "Tek adımda tam çalışan, scripti, collision şekli ve hareketi hazır 2D veya 3D bir karakter sahnesi oluşturur.",
				"parameters": {
					"type": "object",
					"properties": {
						"dimension": { "type": "string", "enum": ["2d", "3d"], "description": "2D veya 3D karakter tipi." },
						"character_name": { "type": "string", "description": "Karakter adı (örn: Player, Enemy)." },
						"speed": { "type": "number", "description": "Hareket hızı (varsayılan: 300.0)." },
						"jump_velocity": { "type": "number", "description": "Zıplama kuvveti (varsayılan: -400.0)." }
					},
					"required": ["dimension", "character_name"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "setup_camera_follow",
				"description": "Aktif sahneye yumuşak takip (smooth follow) özellikli bir kamera ekler ve hedef düğüme bağlar.",
				"parameters": {
					"type": "object",
					"properties": {
						"target_node_path": { "type": "string", "description": "Takip edilecek hedef düğümün yolu (örn: Player)." },
						"zoom": { "type": "number", "description": "Kamera yakınlaştırma oranı (örn: 1.5)." }
					},
					"required": ["target_node_path"]
				}
			}
		}
	]

static func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"create_character_scene":
			return _create_character_scene(args)
		"setup_camera_follow":
			return _setup_camera_follow(args)
		_:
			return AISidebarToolResult.err("UNKNOWN_TOOL", "Bilinmeyen intent aracı: " + tool_name)

static func _create_character_scene(args: Dictionary) -> Dictionary:
	var dim = args.get("dimension", "2d").to_lower()
	var char_name = args.get("character_name", "Player")
	var speed = args.get("speed", 300.0)
	var jump = args.get("jump_velocity", -400.0)
	
	var scene_dir = "res://scenes/"
	var script_dir = "res://scripts/"
	DirAccess.make_dir_recursive_absolute(scene_dir)
	DirAccess.make_dir_recursive_absolute(script_dir)
	
	var scene_path = scene_dir + char_name + ".tscn"
	var script_path = script_dir + char_name + ".gd"
	
	if dim == "2d":
		var root = CharacterBody2D.new()
		root.name = char_name
		
		var col = CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var shape = CapsuleShape2D.new()
		shape.radius = 16.0
		shape.height = 48.0
		col.shape = shape
		root.add_child(col)
		col.owner = root
		
		var gd_code = """extends CharacterBody2D

@export var speed: float = %s
@export var jump_velocity: float = %s

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()
""" % [str(speed), str(jump)]
		
		var write_res = AISidebarScriptTools.execute("create_or_update_script", {
			"file_path": script_path,
			"content": gd_code
		})
		if not write_res.get("success", false):
			return write_res
			
		var scr = load(script_path)
		if scr:
			root.set_script(scr)
			
		var packed = PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, scene_path)
		
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.open_scene_from_path(scene_path)
		
		return AISidebarToolResult.ok({
			"scene_path": scene_path,
			"script_path": script_path
		}, "2D Karakter sahnesi ve scripti oluşturuldu ve editörde açıldı.")
	else:
		var root = CharacterBody3D.new()
		root.name = char_name
		
		var col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape = CapsuleShape3D.new()
		col.shape = shape
		root.add_child(col)
		col.owner = root
		
		var gd_code = """extends CharacterBody3D

@export var speed: float = %s
@export var jump_velocity: float = %s

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
""" % [str(speed), str(jump)]
		
		var write_res = AISidebarScriptTools.execute("create_or_update_script", {
			"file_path": script_path,
			"content": gd_code
		})
		if not write_res.get("success", false):
			return write_res
			
		var scr = load(script_path)
		if scr:
			root.set_script(scr)
			
		var packed = PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, scene_path)
		
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.open_scene_from_path(scene_path)
		
		return AISidebarToolResult.ok({
			"scene_path": scene_path,
			"script_path": script_path
		}, "3D Karakter sahnesi ve scripti oluşturuldu ve editörde açıldı.")

static func _setup_camera_follow(args: Dictionary) -> Dictionary:
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return AISidebarToolResult.err("NO_ACTIVE_SCENE", "Aktif açık bir sahne bulunamadı.")
		
	var tgt_path = args.get("target_node_path", "")
	var zoom_val = args.get("zoom", 1.0)
	
	if not root.has_node(tgt_path):
		return AISidebarToolResult.err("NODE_NOT_FOUND", "Hedef düğüm bulunamadı: " + tgt_path)
		
	var target = root.get_node(tgt_path)
	if target is Node2D:
		var cam = Camera2D.new()
		cam.name = "FollowCamera2D"
		cam.position_smoothing_enabled = true
		cam.zoom = Vector2(zoom_val, zoom_val)
		target.add_child(cam)
		cam.owner = root
		return AISidebarToolResult.ok(null, "Camera2D hedef düğüme eklendi ve yumuşak takip aktifleştirildi.")
	else:
		var cam = Camera3D.new()
		cam.name = "FollowCamera3D"
		cam.position = Vector3(0, 3, 5)
		target.add_child(cam)
		cam.owner = root
		return AISidebarToolResult.ok(null, "Camera3D hedef düğüme eklendi.")
