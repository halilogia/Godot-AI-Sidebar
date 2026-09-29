extends RefCounted
class_name Track

# Procedural oval circuit: returns outer point and inner point for an angle.
static func outer(t: float) -> Vector2:
	var a := t * TAU
	return Vector2(cos(a) * 760.0, sin(a) * 470.0)

static func inner(t: float) -> Vector2:
	var a := t * TAU
	return Vector2(cos(a) * 430.0, sin(a) * 250.0)

static func center_offset() -> Vector2:
	return Vector2.ZERO

static func start_transform(index: int) -> Transform2D:
	var t := 0.0 - float(index) * 0.018
	var p := outer(t).lerp(inner(t), 0.5)
	var dir := (outer(t + 0.004) - outer(t - 0.004)).normalized()
	return Transform2D(dir.angle(), p)

static func draw(g: CanvasItem, laps_total: int) -> void:
	g.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# outfield
	g.draw_rect(Rect2(-1500, -1200, 3000, 2400), Palette.OFFTRACK, true)
	# infield
	g.draw_circle(Vector2.ZERO, 430.0, Palette.BG)
	g.draw_circle(Vector2.ZERO, 250.0, Palette.OFFTRACK.darkened(0.15))
	# grass
	for i in range(720):
		var t := float(i) / 720.0
		var p := outer(t)
		g.draw_circle(p + Vector2(0, 6), 3.0, Palette.BG.lerp(Color.BLACK, 0.4))
	# asphalt ring
	var pts_o := PackedVector2Array()
	var pts_i := PackedVector2Array()
	for i in range(180):
		var t := float(i) / 180.0
		pts_o.append(outer(t))
		pts_i.append(inner(t))
	pts_o.append(pts_o[0])
	pts_i.append(pts_i[0])
	for i in range(pts_o.size() - 1):
		var strip := PackedVector2Array([pts_o[i], pts_i[i], pts_i[i + 1], pts_o[i + 1]])
		var c := Palette.ASPHALT if i % 2 == 0 else Palette.ASPHALT.lerp(Palette.BG, 0.18)
		g.draw_colored_polygon(strip, c)
	# neon edges
	var eo := PackedVector2Array()
	var ei := PackedVector2Array()
	for i in range(181):
		var t := float(i) / 180.0
		eo.append(outer(t))
		ei.append(inner(t))
	g.draw_polyline(eo, Palette.PRIMARY, 4.0, true)
	g.draw_polyline(ei, Palette.ACCENT, 3.0, true)
	# kerbs
	for i in range(60):
		var t := float(i) / 60.0
		g.draw_line(outer(t), inner(t).lerp(outer(t), 0.10), Palette.DANGER, 5.0)
		g.draw_line(inner(t), inner(t).lerp(outer(t), 0.06), Palette.PRIMARY.darkened(0.2), 3.0)
	# start line
	var t0 := 0.0
	g.draw_line(outer(t0), inner(t0), Palette.ACCENT, 8.0)
	for k in range(8):
		var p0 := outer(t0).lerp(inner(t0), float(k) / 8.0)
		var p1 := outer(t0).lerp(inner(t0), (float(k) + 0.5) / 8.0)
		g.draw_line(p0, p1, Palette.TEXT, 4.0)
