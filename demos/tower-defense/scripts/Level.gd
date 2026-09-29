class_name Level
extends RefCounted

const COLS := 30
const ROWS := 15
const CELL := 40.0

var road: Dictionary = {}
var path_cells: Array[Vector2i] = []
var spawn_cell := Vector2i.ZERO
var base_cell := Vector2i.ZERO

static func build() -> Level:
	var l := Level.new()
	l._make_path()
	return l

func _make_path() -> void:
	var pts := [Vector2i(0, 12), Vector2i(8, 12), Vector2i(8, 3), Vector2i(19, 3), Vector2i(19, 11), Vector2i(29, 11)]
	for i in pts.size() - 1:
		_walk(pts[i], pts[i + 1])
	spawn_cell = path_cells[0]
	base_cell = path_cells[path_cells.size() - 1]

func _walk(a: Vector2i, b: Vector2i) -> void:
	var c := a
	_add(c)
	while c != b:
		c.x += signi(b.x - c.x)
		_add(c)
		c.y += signi(b.y - c.y)
		_add(c)

func _add(c: Vector2i) -> void:
	if road.has(c):
		return
	road[c] = true
	path_cells.append(c)

func is_road(c: Vector2i) -> bool:
	return road.has(c)

func is_buildable(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= ROWS:
		return false
	return not road.has(c)

func world_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL * 0.5, c.y * CELL + CELL * 0.5)

func field_size() -> Vector2:
	return Vector2(COLS * CELL, ROWS * CELL)
