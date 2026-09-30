extends Node3D

const WALL_SIZE := Vector3(144.0, 6.0, 1.0)
const HALF := 72.0
const CRATE_SIZE := 1.4
const BAG_SIZE := Vector3(1.2, 0.45, 0.6)

const PLAYER_START := Vector3(0, 0, 12)
var _respawn_timer: float = 0.0
const DUMMY_POSITIONS := [
	Vector3(-7, 0, -12), Vector3(-2, 0, -12), Vector3(3, 0, -12),
	Vector3(-7, 0, -16), Vector3(3, 0, -16),
]


func _ready() -> void:
	_build_walls()
	_build_trenches()
	_build_crates()
	_build_targets()
	_build_enemies()
	_setup_hud()


func _setup_hud() -> void:
	var hud: HUD = $HUD.get_node("Interface")
	hud.set_hint("WASD yürü  •  Shift koş  •  Boşluk zıpla  •  Sol tık ateş  •  R doldur  •  Esc imleci bırak")
	var player := $Player as Player
	player.register_hud(hud)
	player.health_depleted.connect(_on_player_defeated)


## Ölünce 2 saniye sonra aynı noktada yeniden doğar; mermiler ve can tamamen dolar.
func _on_player_defeated() -> void:
	if _respawn_timer > 0.0:
		return
	_respawn_timer = 2.0
	var hud: HUD = $HUD.get_node("Interface")
	hud.set_hint("Yaralandın — 2 saniye içinde yeniden doğacaksın.")


func _process(delta: float) -> void:
	if _respawn_timer <= 0.0:
		return
	_respawn_timer -= delta
	if _respawn_timer > 0.0:
		return
	_respawn_timer = 0.0
	var player := $Player as Player
	player.global_position = PLAYER_START
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.respawn()
	var hud: HUD = $HUD.get_node("Interface")
	hud.set_hint("Yeniden doğdun — şarjörlerin ve yedek mermilerin doldu.")


func _build_walls() -> void:
	var walls := $Walls
	var mat := _material(Palette.SURFACE)
	for side in 4:
		var wall := StaticBody3D.new()
		wall.name = "Wall%d" % side
		var angle := deg_to_rad(90.0 * side)
		wall.transform = Transform3D(Basis(Vector3.UP, angle), _rotated(Vector3(0.0, 3.0, HALF), angle))
		_add_box(wall, WALL_SIZE, Vector3.ZERO, mat)
		walls.add_child(wall)


func _build_trenches() -> void:
	# Sandbag parapets and a few wooden posts: WWII trench cover to fight from.
	var props := $Props
	var bag_mat := _material(Color(0.372549, 0.360784, 0.301961))
	var wood_mat := _material(Color(0.301961, 0.25098, 0.184314))
	var segs := [
		{"a": Vector3(-8, 0, -4), "b": Vector3(6, 0, -4)},
		{"a": Vector3(-8, 0, 2), "b": Vector3(6, 0, 2)},
		{"a": Vector3(-12, 0, 8), "b": Vector3(-12, 0, -8)},
		{"a": Vector3(10, 0, 8), "b": Vector3(10, 0, -8)},
	]
	for i in segs.size():
		var seg: Dictionary = segs[i]
		var from: Vector3 = seg["a"]
		var to: Vector3 = seg["b"]
		var dir := (to - from)
		var count := int(dir.length() / BAG_SIZE.x)
		for s in count:
			var pos := from + dir.normalized() * (BAG_SIZE.x * (s + 0.5))
			for row in 2:
				var bag := StaticBody3D.new()
				bag.name = "Sandbag%d_%d_%d" % [i, s, row]
				bag.position = pos + Vector3(0, BAG_SIZE.y * (row + 0.5), 0)
				var size := BAG_SIZE
				size.x = BAG_SIZE.x * (0.92 if row == 0 else 1.0)
				_add_box(bag, size, Vector3.ZERO, bag_mat)
				props.add_child(bag)
	for i in 6:
		var post := StaticBody3D.new()
		post.name = "Post%d" % i
		post.position = Vector3(-10.0 + i * 4.0, 1.2, -9.0)
		_add_box(post, Vector3(0.18, 2.4, 0.18), Vector3.ZERO, wood_mat)
		props.add_child(post)


func _build_crates() -> void:
	var props := $Props
	var accent := _material(Palette.ACCENT.darkened(0.25))
	var primary := _material(Color(0.32549, 0.360784, 0.317647))
	var layout := [
		Vector3(8, 0.7, 6), Vector3(9.4, 0.7, 6), Vector3(8.7, 2.1, 6),
		Vector3(-9, 0.7, 4), Vector3(-9, 2.1, 4), Vector3(-9, 3.5, 4),
		Vector3(0, 0.7, 11), Vector3(0, 0.7, 12.4), Vector3(1.4, 0.7, 11.7),
		Vector3(14, 0.7, -4), Vector3(15.4, 0.7, -4), Vector3(14.7, 2.1, -4),
	]
	for i in layout.size():
		var crate := StaticBody3D.new()
		crate.name = "Crate%d" % i
		crate.position = layout[i]
		_add_box(crate, Vector3.ONE * CRATE_SIZE, Vector3.ZERO, accent if i % 3 != 0 else primary)
		props.add_child(crate)


func _build_targets() -> void:
	var target_scene: PackedScene = load("res://scenes/TargetDummy.tscn")
	var root := $Targets
	for i in DUMMY_POSITIONS.size():
		var d: Target = target_scene.instantiate()
		d.name = "Dummy%d" % i
		d.position = DUMMY_POSITIONS[i]
		root.add_child(d)


## Haritaya oyuncuyu takip eden düşmanlar yerleştirir.
func _build_enemies() -> void:
	var enemy_scene: PackedScene = load("res://scenes/Enemy.tscn")
	var root := $Enemies
	var spots := [
		Vector3(10, 0, -14), Vector3(-14, 0, -18), Vector3(18, 0, 8),
		Vector3(-20, 0, 12), Vector3(0, 0, -24), Vector3(24, 0, -6),
		Vector3(0, 0, 24), Vector3(-24, 0, -6), Vector3(24, 0, 18),
		Vector3(-24, 0, 18), Vector3(6, 0, 30), Vector3(-6, 0, -32),
	]
	var player := $Player as Node3D
	var i := 0
	while i < spots.size():
		var e: Enemy = enemy_scene.instantiate()
		e.name = "Enemy%d" % i
		e.position = spots[i]
		root.add_child(e)
		e.setup(player)
		i += 1


func _add_box(body: StaticBody3D, size: Vector3, offset: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = offset
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = offset
	body.add_child(col)


func _rotated(v: Vector3, angle: float) -> Vector3:
	return Vector3(v.x * cos(angle) - v.z * sin(angle), v.y, v.x * sin(angle) + v.z * cos(angle))


func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.92
	return m
