extends Node2D

var world: Node2D
var solid_layer: Node2D
var player: CharacterBody2D
var spawn := Vector2.ZERO
var goal_pos := Vector2.ZERO

func _ready() -> void:
	var data := Level.build()
	world = Node2D.new()
	add_child(world)
	solid_layer = Node2D.new()
	world.add_child(solid_layer)
	_build_tiles(data["solid"])
	_build_hazards(data["hazards"])
	for e in data["entities"]:
		_spawn_entity(e)

func _center(v: Vector2i) -> Vector2:
	return Vector2((v.x + 0.5) * Palette.TILE, (v.y + 0.5) * Palette.TILE)

func _build_tiles(solid: Dictionary) -> void:
	for key in solid.keys():
		var p := _center(key)
		var body := StaticBody2D.new()
		body.position = p
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(Palette.TILE, Palette.TILE)
		shape.shape = rect
		body.add_child(shape)
		solid_layer.add_child(body)
		_tile_draw(body, p)

func _tile_draw(node: Node2D, p: Vector2) -> void:
	var d := TileSkin.new()
	d.position = p
	solid_layer.add_child(d)

func _build_hazards(hazards: Dictionary) -> void:
	for key in hazards.keys():
		var p := _center(key)
		var area := Area2D.new()
		area.position = p
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(Palette.TILE, 30)
		cs.shape = rect
		area.add_child(cs)
		area.add_child(Spikes.new())
		area.set_meta("hazard", true)
		area.add_to_group("hazards")
		world.add_child(area)

func _spawn_entity(e: Dictionary) -> void:
	match e["type"]:
		"player":
			player = Player.new()
			player.position = _center(e["tile"])
			player.collision_layer = 2
			player.collision_mask = 1
			world.add_child(player)
			spawn = player.position
		"goal":
			var g := Goal.new()
			g.position = _center(e["tile"])
			world.add_child(g)
			goal_pos = g.position
		"enemy":
			var w := Walker.new()
			w.body = CharacterBody2D.new()
			w.add_child(w.body)
			w.body.collision_layer = 4
			w.body.collision_mask = 1
			w.body.position = Vector2.ZERO
			world.add_child(w)
			w.position = _center(e["tile"])
		"coin":
			var c := Coin.new()
			c.position = _center(e["tile"])
			world.add_child(c)
		"moving":
			var m := MovingPlatform.new()
			m.setup(_center(e["from"]), _center(e["to"]))
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(96, 20)
			cs.shape = rect
			m.add_child(cs)
			world.add_child(m)
