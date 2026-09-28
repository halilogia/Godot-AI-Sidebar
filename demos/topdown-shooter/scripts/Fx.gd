class_name Fx
extends Node2D

func _ready() -> void:
	add_to_group("fx")

func burst(pos: Vector2, col: Color, count: int) -> void:
	var ps := CPUParticles2D.new()
	ps.position = pos
	ps.amount = count
	ps.one_shot = true
	ps.lifetime = 0.35
	ps.explosiveness = 1.0
	ps.direction = Vector2.RIGHT
	ps.spread = 180.0
	ps.initial_velocity_min = 60.0
	ps.initial_velocity_max = 200.0
	ps.scale_amount_min = 2.0
	ps.scale_amount_max = 4.0
	ps.color = col
	ps.emitting = true
	add_child(ps)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(ps.queue_free)
