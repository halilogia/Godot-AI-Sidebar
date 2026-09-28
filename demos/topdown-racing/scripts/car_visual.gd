extends Node2D

@export var body_color := Color(0.9, 0.25, 0.2)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-18, -12, 16, 7), Color(0.08, 0.08, 0.1))
	draw_rect(Rect2(2, -12, 16, 7), Color(0.08, 0.08, 0.1))
	draw_rect(Rect2(-18, 5, 16, 7), Color(0.08, 0.08, 0.1))
	draw_rect(Rect2(2, 5, 16, 7), Color(0.08, 0.08, 0.1))
	var pts := PackedVector2Array([
		Vector2(-26, -11), Vector2(10, -11), Vector2(22, -6),
		Vector2(22, 6), Vector2(10, 11), Vector2(-26, 11)
	])
	draw_colored_polygon(pts, body_color)
	draw_polyline(pts, Color(0.05, 0.05, 0.07), 2.0, true)
	draw_rect(Rect2(-8, -8, 12, 16), Color(0.75, 0.87, 0.95, 0.9))
	draw_rect(Rect2(20, -6, 4, 12), Color(1.0, 0.93, 0.7))
