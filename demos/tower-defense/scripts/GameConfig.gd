class_name GameConfig
extends RefCounted

const COLS := 16
const ROWS := 8
const TILE := 64
const ORIGIN := Vector2(128, 110)

# Grid path in cell coordinates, from spawn (left) to base (right).
const PATH_CELLS: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3),
	Vector2i(2, 4), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5),
	Vector2i(5, 5), Vector2i(5, 4), Vector2i(5, 3), Vector2i(5, 2),
	Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2), Vector2i(9, 2),
	Vector2i(9, 3), Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4),
	Vector2i(12, 4), Vector2i(13, 4), Vector2i(14, 4), Vector2i(15, 4),
]

const START_LIVES := 20
const START_GOLD := 260
