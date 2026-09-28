extends Node2D
class_name Goal

func _ready() -> void:
	add_to_group("goal")

func _process(delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-4, -80, 8, 80), Palette.SURFACE, true)
	var pts := PackedVector2Array([Vector2(4, -80), Vector2(56, -66), Vector2(4, -52)])
	draw_colored_polygon(pts, Palette.ACCENT)
	draw_rect(Rect2(-12, 4, 24, 8), Palette.SURFACE, true)
