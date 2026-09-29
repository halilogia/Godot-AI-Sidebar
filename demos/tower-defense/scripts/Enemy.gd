class_name Enemy
extends Node2D

signal leaked(enemy: Enemy)
signal died(enemy: Enemy)

var level: Level
var index := 0
var hp := 60.0
var max_hp := 60.0
var speed := 70.0
var reward := 10
var body_color := Palette.DANGER
var radius := 11.0
var _flash := 0.0

func setup(l: Level, hp_scale: float, spd: float, col: Color, rad: float) -> void:
	level = l
	max_hp = 60.0 * hp_scale
	hp = max_hp
	speed = spd
	body_color = col
	radius = rad
	reward = 12 if rad > 14.0 else 8
	position = level.world_pos(level.path_cells[0])
	queue_redraw()

func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	var cells := level.path_cells
	if index < cells.size() - 1:
		var target := level.world_pos(cells[index + 1])
		var dir := target - position
		if dir.length() <= speed * delta:
			position = target
			index += 1
		else:
			position += dir.normalized() * speed * delta
	else:
		leaked.emit(self)
		queue_free()
		return
	queue_redraw()

func take_damage(amount: float) -> void:
	hp -= amount
	_flash = 0.1
	if hp <= 0.0:
		died.emit(self)
		queue_free()

func _draw() -> void:
	draw_circle(Vector2(0, 5), radius, Color(0, 0, 0, 0.35))
	var c := Color.WHITE if _flash > 0.0 else body_color
	draw_circle(Vector2.ZERO, radius, c)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 24, c.lightened(0.35), 2.0)
	var w := radius * 2.0
	var f := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-w * 0.5, -radius - 10.0, w, 4.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(-w * 0.5, -radius - 10.0, w * f, 4.0), Palette.ACCENT)
