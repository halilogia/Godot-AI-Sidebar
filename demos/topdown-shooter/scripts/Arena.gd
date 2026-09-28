class_name Arena
extends Node2D

const ARENA := Rect2(0, 0, 880, 560)

var grid_seed := 0

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(ARENA.grow(6), Palette.SURFACE.lightened(0.1), true)
	var r := ARENA
	draw_rect(r, Palette.SURFACE, true)
	# panel grid
	var step := 40
	var x := r.position.x
	while x <= r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Palette.SURFACE.lightened(0.12), 1.0)
		x += step
	var y := r.position.y
	while y <= r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Palette.SURFACE.lightened(0.12), 1.0)
		y += step
	# border
	draw_rect(r, Palette.PRIMARY * Color(1, 1, 1, 0.5), false, 3.0)
	# corner accents
	var c := Palette.ACCENT
	var L := 36.0
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var p: Vector2 = corners[i]
		var sx := 1.0 if (i == 0 or i == 3) else -1.0
		var sy := 1.0 if (i == 0 or i == 1) else -1.0
		draw_line(p, p + Vector2(L * sx, 0), c, 4.0)
		draw_line(p, p + Vector2(0, L * sy), c, 4.0)
