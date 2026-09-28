extends Control

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Palette.VOID, true)
	var top := Color(Palette.SURFACE.r, Palette.SURFACE.g, Palette.SURFACE.b, 0.55)
	draw_rect(Rect2(0, 0, size.x, size.y * 0.5), top, true)
	draw_rect(r, Palette.VOID.darkened(0.3), false, 6.0)
