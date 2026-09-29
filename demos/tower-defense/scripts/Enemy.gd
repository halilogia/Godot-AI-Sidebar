class_name Enemy
extends Node2D

var max_hp := 40.0
var hp := 40.0
var speed := 55.0
var reward := 8
var slow_until := 0.0
var damage := 1
var path_index := 0
var is_boss := false
var flash := 0.0
var _time := 0.0

func setup(p_path: Array, hp_value: float, spd: float, rew: int, dmg: int) -> void:
	max_hp = hp_value
	hp = hp_value
	speed = spd
	reward = rew
	damage = dmg

func _process(delta: float) -> void:
	_time += delta
	if flash > 0.0:
		flash = maxf(0.0, flash - delta)
	queue_redraw()

func tick_move(points: Array, delta: float) -> bool:
	if path_index >= points.size():
		return true
	var target: Vector2 = points[path_index]
	var to := target - global_position
	var step := speed * delta
	if _is_slowed():
		step *= 0.5
	if to.length() <= step:
		global_position = target
		path_index += 1
	else:
		global_position += to.normalized() * step
	return path_index >= points.size()

func _is_slowed() -> bool:
	return Time.get_ticks_msec() / 1000.0 < slow_until

func apply_slow(seconds: float) -> void:
	slow_until = maxf(slow_until, Time.get_ticks_msec() / 1000.0 + seconds)

func take_damage(amount: float) -> bool:
	hp -= amount
	flash = 0.12
	if hp <= 0.0:
		queue_free()
		return true
	return false

func _draw() -> void:
	var body: Color = Palette.ACCENT if is_boss else Palette.DANGER
	if flash > 0.0:
		body = body.lerp(Color.WHITE, 0.75)
	var r := 14.0 if not is_boss else 19.0
	draw_set_transform(Vector2(0, r * 0.75), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r * 0.9, Palette.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, r, body.darkened(0.35))
	draw_circle(Vector2(0, -2), r * 0.62, body)
	var eye := Palette.TEXT
	draw_circle(Vector2(-r * 0.28, -3), r * 0.16, eye)
	draw_circle(Vector2(r * 0.28, -3), r * 0.16, eye)
	var w := 34.0 if not is_boss else 44.0
	var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-w * 0.5, -r - 13.0, w, 6.0), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-w * 0.5 + 1.0, -r - 12.0, (w - 2.0) * ratio, 4.0),
		Palette.FROST if _is_slowed() else Palette.DANGER.lightened(0.25))
	if _is_slowed():
		draw_arc(Vector2.ZERO, r + 5.0, 0.0, TAU, 20, Color(Palette.FROST.r, Palette.FROST.g, Palette.FROST.b, 0.5), 2.0)
