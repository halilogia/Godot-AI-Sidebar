extends Node2D
class_name RaceTrack

const RX := 1500.0
const RY := 900.0
const ROAD_HALF := 190.0
const SEG := 120

var checkpoints: PackedVector2Array = PackedVector2Array()
var start_pos := Vector2.ZERO
var start_angle := 0.0

func _ready() -> void:
	for i in SEG:
		checkpoints.append(_center(i))
	_build_walls()

func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	add_child(body)
	var step := 3
	for s in 2:
		var side: float = 1.0 if s == 0 else -1.0
		for i in range(0, SEG, step):
			var j := (i + step) % SEG
			var a: Vector2 = _center(i) + _dir(i) * ROAD_HALF * side
			var b: Vector2 = _center(j) + _dir(j) * ROAD_HALF * side
			var oa: Vector2 = a + _dir(i) * 300.0 * side
			var ob: Vector2 = b + _dir(j) * 300.0 * side
			var poly := CollisionPolygon2D.new()
			poly.polygon = PackedVector2Array([a, b, ob, oa])
			body.add_child(poly)

func _center(i: int) -> Vector2:
	var a := TAU * float(i) / float(SEG)
	return Vector2(cos(a) * RX, sin(a) * RY)

func _dir(i: int) -> Vector2:
	var a := TAU * float(i) / float(SEG)
	return Vector2(-cos(a), -sin(a) * (RX / RY)).normalized()

func _edge(scale: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in SEG:
		pts.append(_center(i) + _dir(i) * ROAD_HALF * scale)
	pts.append(pts[0])
	return pts

func _draw() -> void:
	draw_circle(Vector2.ZERO, RX + ROAD_HALF + 600.0, Color(0.13, 0.16, 0.13))
	draw_circle(Vector2.ZERO, RX + ROAD_HALF + 120.0, Color(0.18, 0.22, 0.17))
	var outer: PackedVector2Array = _edge(1.0)
	var inner: PackedVector2Array = _edge(-1.0)
	for i in SEG:
		var j := (i + 1) % SEG
		draw_colored_polygon(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]), Color(0.21, 0.22, 0.25))
	for i in range(0, SEG, 2):
		var j := (i + 1) % SEG
		var oc := Color(0.85, 0.8, 0.35, 0.7) if i % 4 == 0 else Color(0.7, 0.25, 0.22, 0.7)
		draw_colored_polygon(PackedVector2Array([outer[i], outer[j], outer[j].lerp(inner[j], 0.06), outer[i].lerp(inner[i], 0.06)]), oc)
		draw_colored_polygon(PackedVector2Array([inner[i], inner[j], inner[j].lerp(outer[j], 0.06), inner[i].lerp(outer[i], 0.06)]), oc)
	for i in range(0, SEG, 4):
		var j := (i + 2) % SEG
		draw_line(outer[i].lerp(inner[i], 0.5), outer[j].lerp(inner[j], 0.5), Color(0.8, 0.8, 0.82, 0.5), 4.0)
	draw_polyline(outer, Color(0.92, 0.92, 0.9, 0.8), 6.0, true)
	draw_polyline(inner, Color(0.92, 0.92, 0.9, 0.8), 6.0, true)
	_start_line()

func _start_line() -> void:
	for r in 8:
		for c in 2:
			var y0: float = lerpf(-ROAD_HALF, ROAD_HALF, float(r) / 8.0)
			var y1: float = lerpf(-ROAD_HALF, ROAD_HALF, float(r + 1) / 8.0)
			var x: float = RX - 16.0 if c == 0 else RX
			var col: Color = Color(0.95, 0.95, 0.95) if (r + c) % 2 == 0 else Color(0.1, 0.1, 0.12)
			draw_rect(Rect2(x, y0, 16.0, y1 - y0), col)
