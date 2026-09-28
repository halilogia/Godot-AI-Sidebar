class_name TileSkin
extends Node2D

const S := float(Palette.TILE)

func _draw() -> void:
	var r := Rect2(-S * 0.5, -S * 0.5, S, S)
	draw_rect(r.grow(2.0), Color(Palette.SURFACE.r, Palette.SURFACE.g, Palette.SURFACE.b, 0.35), true)
	draw_rect(r, Palette.SURFACE, true)
	# top neon edge
	draw_rect(Rect2(-S * 0.5, -S * 0.5, S, 5.0), Palette.PRIMARY, true)
	# inner panel line
	draw_rect(Rect2(-S * 0.5 + 6.0, -S * 0.5 + 12.0, S - 12.0, 3.0), Color(Palette.PRIMARY.r, Palette.PRIMARY.g, Palette.PRIMARY.b, 0.25), true)
	draw_rect(r, Color(Palette.PRIMARY.r, Palette.PRIMARY.g, Palette.PRIMARY.b, 0.35), false, 2.0)
