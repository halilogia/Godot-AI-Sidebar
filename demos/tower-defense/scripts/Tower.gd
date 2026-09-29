class_name Tower
extends Node2D

var level: Level
var cell: Vector2i
var kind := 0
var range_px := 150.0
var damage := 18.0
var fire_rate := 0.8
var cooldown := 0.0
var body_color := Palette.PRIMARY
var fx: Node2D
var _recoil := 0.0
var _aim := 0.0

const STATS := [
	{"name": "Pulse", "cost": 50, "range": 150.0, "dmg": 16.0, "rate": 0.8, "color": Color("46e3c4"), "desc": "Hizli tek atis"},
	{"name": "Frost", "cost": 75, "range": 130.0, "dmg": 8.0, "rate": 1.1, "color": Color("7fd4ff"), "desc": "Yavaslatan mermi"},
	{"name": "Nova", "cost": 110, "range": 175.0, "dmg": 34.0, "rate": 1.8, "color": Color("ffc857"), "desc": "Yavas, agir hasar"},
]

func setup(l: Level, c: Vector2i, k: int) -> void:
	level = l
	cell = c
	kind = k
	var s: Dictionary = STATS[kind]
	range_px = s["range"]
	damage = s["dmg"]
	fire_rate = s["rate"]
	body_color = s["color"]
	position = l.world_pos(c)
	queue_redraw()

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	_recoil = maxf(0.0, _recoil - delta * 4.0)
	queue_redraw()

func fire(enemies: Array) -> void:
	if cooldown > 0.0:
		return
	var target: Enemy = null
	var best := range_px
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d <= best:
			best = d
			target = e
	if target == null:
		return
	cooldown = fire_rate
	_aim = (target.global_position - global_position).angle()
	_recoil = 1.0
	if fx:
		fx.call("shot", global_position, target.global_position, body_color)
	if kind == 1:
		target.speed *= 0.6
		target.queue_redraw()
	target.take_damage(damage)
	if is_instance_valid(target) and fx:
		fx.call("pop", target.global_position, "-%d" % int(damage), body_color)

func _draw() -> void:
	var c := body_color
	draw_circle(Vector2(0, 6), 15.0, Color(0, 0, 0, 0.35))
	draw_rect(Rect2(-14, -14, 28, 28), c.darkened(0.45), true)
	draw_rect(Rect2(-14, -14, 28, 28), c, false, 2.0)
	draw_circle(Vector2.ZERO, 8.0, c)
	var dir := Vector2(cos(_aim), sin(_aim))
	var barrel: Vector2 = dir * (15.0 - _recoil * 5.0)
	draw_line(Vector2.ZERO, barrel, c.lightened(0.45), 5.0)
