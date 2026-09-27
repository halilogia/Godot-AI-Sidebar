class_name Level
extends Node2D

signal goal_reached

const TILE := 32.0
const GROUND_THICK := 96.0
const ENEMY_SCENE: PackedScene = preload("res://scenes/Enemy.tscn")

@export var seed_value: int = 12345
@export var segment_count: int = 13

var spawn_position: Vector2 = Vector2(96.0, -40.0)
var goal_position: Vector2 = Vector2.ZERO
var bounds: Rect2 = Rect2(-200.0, -600.0, 6000.0, 1200.0)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _terrain: StaticBody2D
var _decor: Node2D
var _entities: Node2D
var _segments: Array[Rect2] = []


func _ready() -> void:
	_rng.seed = seed_value

	_decor = Node2D.new()
	_decor.z_index = -10
	add_child(_decor)

	_terrain = StaticBody2D.new()
	_terrain.collision_layer = 1
	_terrain.collision_mask = 0
	add_child(_terrain)

	_entities = Node2D.new()
	add_child(_entities)

	_build_terrain()
	_build_mountains()
	_build_goal()
	_spawn_enemies()


func _build_mountains() -> void:
	var x: float = -400.0
	while x < bounds.end.x + 600.0:
		var w: float = _rng.randf_range(220.0, 420.0)
		var h: float = _rng.randf_range(90.0, 210.0)
		var shade: float = _rng.randf_range(0.10, 0.20)
		_add_decor_poly(
			PackedVector2Array([Vector2(x, 40.0), Vector2(x + w * 0.5, 40.0 - h), Vector2(x + w, 40.0)]),
			Color(shade, shade * 1.2, shade * 1.8)
		)
		x += w * _rng.randf_range(0.55, 0.95)


func _build_terrain() -> void:
	var start_w: float = 8.0 * TILE
	_add_ground(Rect2(0.0, 0.0, start_w, GROUND_THICK))
	_segments.append(Rect2(0.0, 0.0, start_w, GROUND_THICK))
	spawn_position = Vector2(TILE * 2.0, -40.0)

	var x: float = start_w
	var right: float = start_w
	for i in segment_count:
		var gap: float = TILE * _rng.randf_range(1.5, 3.0)
		x += gap
		var w: float = TILE * _rng.randf_range(3.0, 7.0)
		var y: float = 0.0
		if i % 3 == 2:
			y = -TILE * _rng.randf_range(0.0, 2.0)
		var seg := Rect2(x, y, w, GROUND_THICK - y)
		_add_ground(seg)
		_segments.append(seg)
		if _rng.randf() < 0.7:
			var pw: float = TILE * _rng.randf_range(2.0, 3.5)
			var px: float = x - gap * 0.5 - pw * 0.5
			var py: float = -TILE * _rng.randf_range(3.0, 5.0)
			_add_platform(Rect2(px, py, pw, TILE * 0.6))
		right = x + w
		x = right

	var end_w: float = 8.0 * TILE
	_add_ground(Rect2(x, 0.0, end_w, GROUND_THICK))
	right = x + end_w
	goal_position = Vector2(x + end_w * 0.5, 0.0)
	bounds = Rect2(-200.0, -600.0, right + 400.0, 1200.0)


func _build_goal() -> void:
	var h: float = 130.0
	var pole := Polygon2D.new()
	pole.polygon = PackedVector2Array([Vector2(0.0, 0.0), Vector2(8.0, 0.0), Vector2(8.0, -h), Vector2(0.0, -h)])
	pole.color = Color(0.88, 0.90, 0.95)
	pole.position = goal_position
	_entities.add_child(pole)

	var flag := Polygon2D.new()
	flag.polygon = PackedVector2Array([Vector2(0.0, 0.0), Vector2(50.0, 15.0), Vector2(0.0, 30.0)])
	flag.color = Color(0.95, 0.29, 0.36)
	flag.position = goal_position + Vector2(8.0, -h)
	_entities.add_child(flag)

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60.0, h)
	shape.shape = rect
	shape.position = Vector2(30.0, -h * 0.5)
	area.add_child(shape)
	area.position = goal_position
	area.body_entered.connect(_on_goal_body_entered)
	_entities.add_child(area)


func _spawn_enemies() -> void:
	for i in range(1, _segments.size()):
		var seg: Rect2 = _segments[i]
		if seg.size.x < TILE * 4.0 or _rng.randf() > 0.55:
			continue
		if goal_position.x - seg.end.x < TILE * 2.0:
			continue
		var count: int = 1 if _rng.randf() < 0.75 else 2
		for n in count:
			var ex: float = _rng.randf_range(seg.position.x + TILE, seg.end.x - TILE)
			var enemy := ENEMY_SCENE.instantiate() as Enemy
			enemy.position = Vector2(ex, seg.position.y)
			_entities.add_child(enemy)


func _on_goal_body_entered(body: Node2D) -> void:
	if body is Player:
		goal_reached.emit()


func _add_ground(rect: Rect2) -> void:
	_add_rect(rect, Color(0.20, 0.24, 0.34))
	_add_rect(Rect2(rect.position, Vector2(rect.size.x, 8.0)), Color(0.36, 0.72, 0.45))


func _add_platform(rect: Rect2) -> void:
	_add_rect(rect, Color(0.24, 0.28, 0.40))
	_add_rect(Rect2(rect.position, Vector2(rect.size.x, 6.0)), Color(0.85, 0.72, 0.35))


func _add_rect(rect: Rect2, color: Color) -> void:
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.position = rect.position + rect.size * 0.5
	_terrain.add_child(collider)

	var p: Vector2 = rect.position
	var s: Vector2 = rect.size
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([p, p + Vector2(s.x, 0.0), p + s, p + Vector2(0.0, s.y)])
	poly.color = color
	_terrain.add_child(poly)


func _add_decor_poly(points: PackedVector2Array, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	_decor.add_child(poly)
