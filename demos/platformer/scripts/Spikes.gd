class_name Spikes
extends Node2D

func _draw() -> void:
	var w := 56.0
	var h := 28.0
	for i in 3:
		var x := -w * 0.5 + i * (w / 3.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, h * 0.5), Vector2(x + w / 6.0, -h * 0.5), Vector2(x + w / 3.0, h * 0.5)
		]), Palette.DANGER)
	draw_rect(Rect2(-w * 0.5, h * 0.5 - 3.0, w, 4.0), Color(Palette.DANGER.r, Palette.DANGER.g, Palette.DANGER.b, 0.6), true)
