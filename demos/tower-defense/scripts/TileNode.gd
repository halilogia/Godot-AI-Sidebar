class_name TileNode
extends Node2D

var level: Level

func _draw() -> void:
	var fs := level.field_size()
	var c := Level.CELL
	var x := c
	while x < fs.x:
		draw_line(Vector2(x, 0), Vector2(x, fs.y), Palette.GRID, 1.0)
		x += c
	var y := c
	while y < fs.y:
		draw_line(Vector2(0, y), Vector2(fs.x, y), Palette.GRID, 1.0)
		y += c
