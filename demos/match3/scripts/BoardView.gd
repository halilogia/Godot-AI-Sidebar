extends Node2D

const CELL := 74.0
const SIZE := 8
const ORIGIN := Vector2(344.0, 76.0)


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	var frame := Rect2(ORIGIN - Vector2(12, 12), Vector2(CELL * SIZE + 24, CELL * SIZE + 24))
	draw_rect(frame, Palette.CELL, true)
	draw_rect(frame, Palette.CELL_HI, false, 2.0)
	for y in SIZE:
		for x in SIZE:
			var tint := 0.0 if (x + y) % 2 == 0 else 1.0
			var c := Palette.CELL.lerp(Palette.CELL_HI, 0.25 * tint)
			var rect := Rect2(ORIGIN + Vector2(x * CELL + 3, y * CELL + 3), Vector2(CELL - 6, CELL - 6))
			draw_rect(rect, c, true)
