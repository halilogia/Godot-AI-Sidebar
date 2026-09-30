extends Node3D
## 2. Dünya Savaşı temalı 144x144 test haritası: zemin, harabe binalar, siperler, ağaçlar, düşmanlar, oyuncu ve arayüz.

const MAP_HALF := 72.0
const ENEMY_COUNT := 14

var rng := RandomNumberGenerator.new()
var player: Player
var enemies: Array[Enemy] = []
var mats: Dictionary = {}

func _ready() -> void:
	rng.seed = 1944
	_setup_environment()
	_build_ground()
	_build_walls()
	_build_ruins()
	_build_cover()
	_build_trees()
	_spawn_player()
	_spawn_enemies()
	var hud := Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.bind(player)

const MODEL_DIR := "res://assets/models/"

## Blender Copilot'tan (MCP ile modellenmiş) .glb: yoksa null döner ve eski ilkel şekil kullanılır.
func _model(file: String) -> Node3D:
	var scene := load(MODEL_DIR + file) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null

func _merged_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for c in node.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.transform * mi.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

## Model + çarpışma kutusu (modelin kendi sınırından; uniform ölçek).
func _static_model(file: String, pos: Vector3, yaw: float, uniform_scale: float, box_shrink: Vector3 = Vector3.ONE) -> bool:
	var model := _model(file)
	if model == null:
		return false
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = yaw
	body.scale = Vector3.ONE * uniform_scale
	body.add_child(model)
	add_child(body)
	var aabb := _merged_aabb(model)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(aabb.size.x * box_shrink.x, aabb.size.y * box_shrink.y, aabb.size.z * box_shrink.z)
	cs.shape = shape
	cs.position = aabb.get_center()
	body.add_child(cs)
	return true

func _mat(key: String, color: Color, rough: float = 0.9) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	mats[key] = m
	return m

func _setup_environment() -> void:
	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.3, 0.45, 0.62)
	sky.sky_horizon_color = Color(0.66, 0.72, 0.76)
	sky.ground_horizon_color = Color(0.5, 0.46, 0.4)
	sky.ground_bottom_color = Color(0.2, 0.2, 0.18)
	var sky_res := Sky.new()
	sky_res.sky_material = sky
	env.background_mode = Environment.BG_SKY
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.68, 0.7)
	env.fog_density = 0.003
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

func _static_box(size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	body.position = pos
	parent.add_child(body)
	return body

func _build_ground() -> void:
	_static_box(Vector3(MAP_HALF * 2.0, 1.0, MAP_HALF * 2.0), Vector3(0, -0.5, 0), _mat("ground", Color(0.27, 0.36, 0.2)))
	# yol şeridi
	var road := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(7.0, MAP_HALF * 2.0)
	road.mesh = pm
	road.material_override = _mat("road", Color(0.28, 0.25, 0.21))
	road.position = Vector3(0, 0.02, 0)
	add_child(road)

func _build_walls() -> void:
	var wall_mat := _mat("boundary", Color(0.22, 0.2, 0.18))
	var h := 6.0
	var t := 1.0
	_static_box(Vector3(MAP_HALF * 2.0, h, t), Vector3(0, h * 0.5, -MAP_HALF), wall_mat)
	_static_box(Vector3(MAP_HALF * 2.0, h, t), Vector3(0, h * 0.5, MAP_HALF), wall_mat)
	_static_box(Vector3(t, h, MAP_HALF * 2.0), Vector3(-MAP_HALF, h * 0.5, 0), wall_mat)
	_static_box(Vector3(t, h, MAP_HALF * 2.0), Vector3(MAP_HALF, h * 0.5, 0), wall_mat)

func _build_ruins() -> void:
	var brick := _mat("brick", Color(0.5, 0.36, 0.3))
	var plaster := _mat("plaster", Color(0.62, 0.58, 0.5))
	for i in 16:
		var c := Vector3(rng.randf_range(-58, 58), 0, rng.randf_range(-58, 58))
		if absf(c.x) < 6.0 and absf(c.z) < 8.0:
			continue
		var w := rng.randf_range(7.0, 12.0)
		var d := rng.randf_range(6.0, 10.0)
		var h := rng.randf_range(3.2, 5.0)
		var m := brick if i % 2 == 0 else plaster
		# dört duvar, ön duvarda kapı boşluğu, bir duvar yıkık (alçak)
		_static_box(Vector3(w, h, 0.4), c + Vector3(0, h * 0.5, -d * 0.5), m)
		_static_box(Vector3(0.4, h, d), c + Vector3(-w * 0.5, h * 0.5, 0), m)
		_static_box(Vector3(0.4, h * 0.45, d), c + Vector3(w * 0.5, h * 0.225, 0), m)
		var gap := 2.4
		var half := (w - gap) * 0.5
		_static_box(Vector3(half, h, 0.4), c + Vector3(-(gap + half) * 0.5, h * 0.5, d * 0.5), m)
		_static_box(Vector3(half, h, 0.4), c + Vector3((gap + half) * 0.5, h * 0.5, d * 0.5), m)
		_static_box(Vector3(gap, h * 0.3, 0.4), c + Vector3(0, h * 0.85, d * 0.5), m)

func _build_cover() -> void:
	var crate := _mat("crate", Color(0.42, 0.3, 0.18))
	var sand := _mat("sand", Color(0.6, 0.53, 0.38))
	for i in 46:
		var p := Vector3(rng.randf_range(-66, 66), 0, rng.randf_range(-66, 66))
		if absf(p.x) < 4.0 and absf(p.z) < 4.0:
			continue
		var yaw := rng.randf_range(0, PI)
		if i % 3 == 0:
			if not _static_model("crate.glb", p, yaw, 1.25):
				_static_box(Vector3(1.2, 1.2, 1.2), p + Vector3(0, 0.6, 0), crate)
		elif i % 3 == 1:
			if not _static_model("sandbags.glb", p, yaw, 1.0):
				var b := _static_box(Vector3(rng.randf_range(3.0, 6.0), 1.1, 0.8), p + Vector3(0, 0.55, 0), sand)
				b.rotation.y = yaw
		else:
			if not _static_model("barrel.glb", p, yaw, 1.15):
				_static_box(Vector3(0.9, 1.0, 0.9), p + Vector3(0, 0.5, 0), crate)
	for z in [-7.0, -12.0, -17.0]:
		_static_model("jerrycan.glb", Vector3(-3.5, 0, z), 0.4, 1.0)
		_static_model("jerrycan.glb", Vector3(3.5, 0, z), -0.4, 1.0)

func _build_trees() -> void:
	var trunk := _mat("trunk", Color(0.25, 0.18, 0.12))
	var leaf := _mat("leaf", Color(0.2, 0.3, 0.16))
	for i in 60:
		var p := Vector3(rng.randf_range(-68, 68), 0, rng.randf_range(-68, 68))
		if absf(p.x) < 5.0:
			continue
		if i % 5 == 4:
			if _static_model("rock.glb", p, rng.randf_range(0, TAU), rng.randf_range(1.2, 2.6)):
				continue
		elif _static_model("tree.glb", p, rng.randf_range(0, TAU), rng.randf_range(1.0, 1.7), Vector3(0.18, 1.0, 0.18)):
			continue
		var h := rng.randf_range(4.0, 7.5)
		var body := StaticBody3D.new()
		body.position = p
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3
		cyl.height = h
		cs.shape = cyl
		cs.position.y = h * 0.5
		body.add_child(cs)
		var tm := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = 0.32
		cm.height = h
		tm.mesh = cm
		tm.position.y = h * 0.5
		tm.material_override = trunk
		body.add_child(tm)
		var lm := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(1.6, 2.6)
		sm.height = sm.radius * 1.6
		lm.mesh = sm
		lm.position.y = h
		lm.material_override = leaf
		body.add_child(lm)
		add_child(body)

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	player.spawn_position = player.position

func _spawn_enemies() -> void:
	for i in ENEMY_COUNT:
		var e := Enemy.new()
		e.name = "Enemy%d" % i
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(32.0, 62.0)
		e.position = Vector3(cos(angle) * dist, 0.1, sin(angle) * dist)
		e.player = player
		add_child(e)
		enemies.append(e)
