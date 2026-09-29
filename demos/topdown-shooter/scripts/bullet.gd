class_name Bullet
extends Area2D

var direction := Vector2.RIGHT
var speed := 620.0
var damage := 1

func _ready() -> void:
	monitoring = true
	monitorable = false

func _process(delta: float) -> void:
	position += direction * speed * delta
	if position.x < -40.0 or position.x > 1320.0 or position.y < -40.0 or position.y > 760.0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Palette.PRIMARY)
	draw_circle(Vector2.ZERO, 9.0, Color(Palette.PRIMARY, 0.25))
