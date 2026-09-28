class_name Bullet
extends Area2D

var direction := Vector2.RIGHT
var speed := 620.0
var damage := 1
var life := 1.6

func _ready() -> void:
	add_to_group("bullets")
	monitoring = false
	var dot := CircleShape2D.new()
	dot.radius = 4.0
	var cs := CollisionShape2D.new()
	cs.shape = dot
	add_child(cs)
	var s := 8.0
	scale = Vector2(s, s) * 0.01
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(s, s), 0.06)
	modulate = Palette.ACCENT
	rotation = direction.angle()

func _process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	modulate.a = clampf(life / 0.4, 0.0, 1.0)
	if life <= 0.0:
		queue_free()
