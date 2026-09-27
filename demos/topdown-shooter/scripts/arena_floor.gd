extends Node2D

## Arena zemin cizgilerini cizer (gorsel katman, carpisma yok).

@export var arena_size: Vector2 = Vector2(2400, 1600)
@export var cell: float = 100.0
@export var line_color: Color = Color(1, 1, 1, 0.05)


func _draw() -> void:
	var x := cell
	while x < arena_size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, arena_size.y), line_color, 1.0)
		x += cell
	var y := cell
	while y < arena_size.y:
		draw_line(Vector2(0.0, y), Vector2(arena_size.x, y), line_color, 1.0)
		y += cell
	draw_rect(Rect2(Vector2.ZERO, arena_size), Color(0.32, 0.75, 1.0, 0.25), false, 4.0)
