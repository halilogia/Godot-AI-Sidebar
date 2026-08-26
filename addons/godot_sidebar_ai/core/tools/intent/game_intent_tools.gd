@tool
extends "res://addons/godot_sidebar_ai/core/tools/tool_base.gd"
class_name AISidebarGameIntentTools

## Yüksek Seviyeli Oyun Üretim Araçları (Intent-Based Composite Tools) (SRP).
## Tek komutla çalışan, çok adımlı Godot işlemlerini encapsulate eden araçlar.

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
				"name": "create_enemy_scene",
				"description": "Devriye gezen veya oyuncuyu takip eden 2D/3D düşman karakter sahnesi ve scripti oluşturur.",
				"parameters": {
					"type": "object",
					"properties": {
						"enemy_name": { "type": "string", "description": "Düşman adı (örn: Goblin, Slime)." },
						"dimension": { "type": "string", "enum": ["2d", "3d"], "description": "2D veya 3D." },
						"patrol_range": { "type": "number", "description": "Devriye mesafesi (varsayılan: 200.0)." }
					},
					"required": ["enemy_name"]
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "create_ui_hud",
				"description": "Can barı (ProgressBar), skor etiketi ve para sayacı içeren hazır bir Control HUD sahnesi oluşturur.",
				"parameters": {
					"type": "object",
					"properties": {
						"hud_name": { "type": "string", "description": "HUD sahne adı (varsayılan: GameHUD)." }
					}
				}
			}
		},
		{
			"type": "function",
			"function": {
				"name": "create_interactable",
				"description": "Oyuncunun yaklaştığında 'E tuşuna bas' uyarısı çıkaran etkileşimli alan (Area2D/Area3D) sahnesi kurar.",
				"parameters": {
					"type": "object",
					"properties": {
						"object_name": { "type": "string", "description": "Nesne adı (örn: Chest, Door, NPC)." },
						"prompt_message": { "type": "string", "description": "Gösterilecek mesaj (örn: '[E] Aç')." }
					},
					"required": ["object_name"]
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
		"create_enemy_scene":
			return _create_enemy_scene(args)
		"create_ui_hud":
			return _create_ui_hud(args)
		"create_interactable":
			return _create_interactable(args)
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
		
		if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
			if EditorInterface.has_method("get_resource_filesystem"):
				EditorInterface.get_resource_filesystem().scan()
			if EditorInterface.has_method("open_scene_from_path"):
				EditorInterface.open_scene_from_path(scene_path)
				
		return AISidebarToolResult.ok({
			"scene_path": scene_path,
			"script_path": script_path
		}, "✓ 2D Karakter (" + char_name + ") sahnesi ve scripti oluşturuldu.")
	else:
		var root = CharacterBody3D.new()
		root.name = char_name
		
		var col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape = CapsuleShape3D.new()
		shape.radius = 0.5
		shape.height = 1.8
		col.shape = shape
		root.add_child(col)
		col.owner = root
		
		var gd_code = """extends CharacterBody3D

@export var speed: float = %s
@export var jump_velocity: float = %s

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

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
		
		if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
			if EditorInterface.has_method("get_resource_filesystem"):
				EditorInterface.get_resource_filesystem().scan()
			if EditorInterface.has_method("open_scene_from_path"):
				EditorInterface.open_scene_from_path(scene_path)
				
		return AISidebarToolResult.ok({
			"scene_path": scene_path,
			"script_path": script_path
		}, "✓ 3D Karakter (" + char_name + ") sahnesi ve scripti oluşturuldu.")

static func _create_enemy_scene(args: Dictionary) -> Dictionary:
	var enemy_name = args.get("enemy_name", "Enemy")
	var dim = args.get("dimension", "2d").to_lower()
	var patrol = args.get("patrol_range", 200.0)
	
	var scene_dir = "res://scenes/"
	var script_dir = "res://scripts/"
	DirAccess.make_dir_recursive_absolute(scene_dir)
	DirAccess.make_dir_recursive_absolute(script_dir)
	
	var scene_path = scene_dir + enemy_name + ".tscn"
	var script_path = script_dir + enemy_name + ".gd"
	
	var gd_code = """extends CharacterBody2D

@export var speed: float = 100.0
@export var patrol_distance: float = %s

var start_x: float = 0.0
var direction: int = 1

func _ready() -> void:
	start_x = position.x

func _physics_process(delta: float) -> void:
	if abs(position.x - start_x) > patrol_distance:
		direction *= -1
		
	velocity.x = direction * speed
	move_and_slide()
""" % [str(patrol)]
	
	var write_res = AISidebarScriptTools.execute("create_or_update_script", {
		"file_path": script_path,
		"content": gd_code
	})
	if not write_res.get("success", false):
		return write_res
		
	var root = CharacterBody2D.new()
	root.name = enemy_name
	var col = CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)
	col.shape = shape
	root.add_child(col)
	col.owner = root
	
	var scr = load(script_path)
	if scr:
		root.set_script(scr)
		
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, scene_path)
	
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
		if EditorInterface.has_method("get_resource_filesystem"):
			EditorInterface.get_resource_filesystem().scan()
		if EditorInterface.has_method("open_scene_from_path"):
			EditorInterface.open_scene_from_path(scene_path)
			
	return AISidebarToolResult.ok({"scene_path": scene_path}, "✓ Düşman (" + enemy_name + ") devriye sahnesi oluşturuldu.")

static func _create_ui_hud(args: Dictionary) -> Dictionary:
	var hud_name = args.get("hud_name", "GameHUD")
	var scene_path = "res://scenes/" + hud_name + ".tscn"
	DirAccess.make_dir_recursive_absolute("res://scenes/")
	
	var root = Control.new()
	root.name = hud_name
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bar = ProgressBar.new()
	bar.name = "HealthBar"
	bar.value = 100.0
	bar.custom_minimum_size = Vector2(200, 24)
	bar.position = Vector2(20, 20)
	root.add_child(bar)
	bar.owner = root
	
	var score_lbl = Label.new()
	score_lbl.name = "ScoreLabel"
	score_lbl.text = "Skor: 0"
	score_lbl.position = Vector2(20, 55)
	root.add_child(score_lbl)
	score_lbl.owner = root
	
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, scene_path)
	
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
		if EditorInterface.has_method("get_resource_filesystem"):
			EditorInterface.get_resource_filesystem().scan()
		if EditorInterface.has_method("open_scene_from_path"):
			EditorInterface.open_scene_from_path(scene_path)
			
	return AISidebarToolResult.ok({"scene_path": scene_path}, "✓ Oyun HUD UI sahnesi (" + hud_name + ") oluşturuldu.")

static func _create_interactable(args: Dictionary) -> Dictionary:
	var obj_name = args.get("object_name", "InteractableChest")
	var prompt = args.get("prompt_message", "[E] Etkileşime Geç")
	var scene_path = "res://scenes/" + obj_name + ".tscn"
	var script_path = "res://scripts/" + obj_name + ".gd"
	
	DirAccess.make_dir_recursive_absolute("res://scenes/")
	DirAccess.make_dir_recursive_absolute("res://scripts/")
	
	var gd_code = """extends Area2D

signal interacted()

@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and prompt_label and prompt_label.visible:
		interacted.emit()
		print("Etkileşim gerçekleşti: ", name)

func _on_body_entered(body: Node2D) -> void:
	if body.name.begins_with("Player") and prompt_label:
		prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name.begins_with("Player") and prompt_label:
		prompt_label.visible = false
"""
	AISidebarScriptTools.execute("create_or_update_script", {"file_path": script_path, "content": gd_code})
	
	var root = Area2D.new()
	root.name = obj_name
	
	var col = CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 48.0
	col.shape = shape
	root.add_child(col)
	col.owner = root
	
	var lbl = Label.new()
	lbl.name = "PromptLabel"
	lbl.text = prompt
	lbl.position = Vector2(-40, -60)
	root.add_child(lbl)
	lbl.owner = root
	
	var scr = load(script_path)
	if scr:
		root.set_script(scr)
		
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, scene_path)
	
	if Engine.is_editor_hint() and ClassDB.class_exists("EditorInterface"):
		if EditorInterface.has_method("get_resource_filesystem"):
			EditorInterface.get_resource_filesystem().scan()
		if EditorInterface.has_method("open_scene_from_path"):
			EditorInterface.open_scene_from_path(scene_path)
			
	return AISidebarToolResult.ok({"scene_path": scene_path}, "✓ Etkileşimli nesne (" + obj_name + ") sahnesi oluşturuldu.")

static func _setup_camera_follow(args: Dictionary) -> Dictionary:
	if not Engine.is_editor_hint() or not ClassDB.class_exists("EditorInterface"):
		return AISidebarToolResult.err("EDITOR_REQUIRED", "Kamera kurulumu editör gerektirir.")
		
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
		return AISidebarToolResult.ok(null, "✓ Camera2D hedef düğüme eklendi ve yumuşak takip aktifleştirildi.")
	else:
		var cam = Camera3D.new()
		cam.name = "FollowCamera3D"
		cam.position = Vector3(0, 3, 5)
		target.add_child(cam)
		cam.owner = root
		return AISidebarToolResult.ok(null, "✓ Camera3D hedef düğüme eklendi.")
