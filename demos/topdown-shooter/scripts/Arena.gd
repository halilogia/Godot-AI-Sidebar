class_name Arena
extends Node2D

@export var size := Vector2(1280, 720)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BG_DEEP)
	var steps := 24
	var step := size.y / float(steps)
	for i in range(steps + 1):
		var y := i * step
		var t := float(i) / float(steps)
		draw_line(Vector2(0, y), Vector2(size.x, y), Palette.BG_FLOOR.lerp(Palette.BG_DEEP, t), 1.0)
	for i in range(41):
		var x := i * (size.x / 40.0)
		draw_line(Vector2(x, 0), Vector2(x, size.y), Palette.GRID, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Palette.PRIMARY.darkened(0.3), false, 3.0)
