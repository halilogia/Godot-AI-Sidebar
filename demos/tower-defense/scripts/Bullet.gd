class_name Bullet
extends Node2D

var target: Enemy = null
var speed := 420.0
var damage := 10.0
var slow := false
var from_cell := Vector2i.ZERO
var life := 0.0
var arrived := false

func _process(delta: float) -> void:
	life += delta
	if arrived or life > 3.0 or target == null or not is_instance_valid(target):
		if not arrived:
			queue_free()
		return
	var to := target.global_position - global_position
	if to.length() <= speed * delta:
		global_position = target.global_position
		arrived = true
		return
	global_position += to.normalized() * speed * delta
	queue_redraw()

func _draw() -> void:
	var c: Color = Palette.FROST if slow else Palette.PRIMARY
	if slow:
		draw_circle(Vector2.ZERO, 6.0, Color(c.r, c.g, c.b, 0.35))
	draw_circle(Vector2.ZERO, 3.5, c)
