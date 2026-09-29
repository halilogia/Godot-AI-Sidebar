class_name Gem
extends Node2D

const RADIUS := 28.0

var type: int = 0
var selected: bool = false


func setup(p_type: int) -> void:
	type = p_type
	queue_redraw()


func _draw() -> void:
	var base: Color = Palette.GEM_COLORS[type % Palette.GEM_COLORS.size()]
	var pts := _shape_points()
	# soft shadow
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, 4))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
	# glow
	var glow := PackedVector2Array()
	for p in pts:
		glow.append(p * 1.18)
	draw_colored_polygon(glow, Color(base.r, base.g, base.b, 0.18))
	# body
	draw_colored_polygon(pts, base)
	# top-left highlight
	var hi := PackedVector2Array()
	for i in pts.size():
		hi.append(pts[i].lerp(Vector2(-7, -7), 0.42))
	draw_colored_polygon(hi, Color(1, 1, 1, 0.16))
	# outline
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(base.r * 0.55, base.g * 0.5, base.b * 0.6, 0.9), 2.5, true)
	# gloss dot
	draw_circle(Vector2(-9, -10), 4.5, Color(1, 1, 1, 0.35))
	if selected:
		draw_arc(Vector2.ZERO, RADIUS + 5, 0, TAU, 40, Palette.ACCENT, 3.0, true)


func _shape_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	match type % 6:
		0:  # circle
			for i in 24:
				pts.append(Vector2.from_angle(TAU * i / 24.0) * RADIUS)
		1:  # square
			var h := RADIUS * 0.84
			pts = PackedVector2Array([
				Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)
			])
		2:  # diamond
			pts = PackedVector2Array([
				Vector2(0, -RADIUS), Vector2(RADIUS * 0.92, 0),
				Vector2(0, RADIUS), Vector2(-RADIUS * 0.92, 0)
			])
		3:  # triangle
			for i in 3:
				var a := -PI / 2.0 + TAU * i / 3.0
				pts.append(Vector2.from_angle(a) * RADIUS)
		4:  # hexagon
			for i in 6:
				pts.append(Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * RADIUS)
		5:  # star
			for i in 10:
				var rad := RADIUS if i % 2 == 0 else RADIUS * 0.46
				pts.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 10.0) * rad)
	return pts
