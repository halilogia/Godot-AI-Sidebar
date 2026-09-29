extends Node3D
## Procedural lab environment: floor, pillars, trim lines, coin scatter.

const COIN := preload("res://scenes/Collectible.tscn")
const HALF := 20.0

var coins: Node3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	coins = get_node_or_null("Coins")
	_build_room()
	_build_trim()
	_build_pillars()
	_build_coins()

func _build_room() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	var bm := BoxMesh.new()
	bm.size = Vector3(HALF * 2.0, 0.4, HALF * 2.0)
	bm.material = _mat(Palette.SURFACE, 0.85)
	var mesh := MeshInstance3D.new()
	mesh.mesh = bm
	body.add_child(mesh)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bm.size
	cs.shape = box
	body.add_child(cs)
	body.position.y = -0.2
	add_child(body)

func _build_pillars() -> void:
	var bm := CylinderMesh.new()
	bm.top_radius = 0.5
	bm.bottom_radius = 0.6
	bm.height = 6.0
	bm.radial_segments = 12
	bm.material = _mat(Palette.SURFACE, 0.6)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.62
	cap.bottom_radius = 0.62
	cap.height = 0.12
	cap.radial_segments = 12
	cap.material = _mat(Palette.PRIMARY, 0.4, 0.5)
	for x in [-12.0, 12.0]:
		for z in [-12.0, -4.0, 4.0, 12.0]:
			var m := MeshInstance3D.new()
			m.mesh = bm
			add_child(m)
			m.position = Vector3(x, 3.0, z)
			var c := MeshInstance3D.new()
			c.mesh = cap
			add_child(c)
			c.position = Vector3(x, 5.9, z)

func _build_trim() -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3(HALF * 2.0, 0.08, 0.08)
	bm.material = _mat(Palette.PRIMARY, 0.4, 0.9)
	for z in [-HALF, 0.0, HALF]:
		var d := MeshInstance3D.new()
		d.mesh = bm
		add_child(d)
		d.position = Vector3(0, 0.02, z)
	for x in [-HALF, 0.0, HALF]:
		var d := MeshInstance3D.new()
		d.mesh = bm
		d.rotate_y(PI * 0.5)
		add_child(d)
		d.position = Vector3(x, 0.02, 0)

func _build_coins() -> void:
	if coins == null:
		return
	rng.seed = 12345
	for i in 12:
		var c: Node3D = COIN.instantiate()
		coins.add_child(c)
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.0, 16.0)
		c.position = Vector3(sin(a) * r, 1.0, cos(a) * r)

func _mat(color: Color, rough: float, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emis
	return m
