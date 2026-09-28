class_name Enemy
extends CharacterBody2D

var speed := 120.0
var hp := 2
var contact_cd := 0.0
var flash := 0.0
var target: Node2D
var bounds := Rect2(0, 0, 800, 500)
var points := 10

func _ready() -> void:
	add_to_group("enemy")
	var c := CircleShape2D.new()
	c.radius = 12.0
	var cs := CollisionShape2D.new()
	cs.shape = c
	add_child(cs)

func _physics_process(delta: float) -> void:
	contact_cd = maxf(0.0, contact_cd - delta)
	flash = maxf(0.0, flash - delta)
	if flash > 0.0:
		modulate = Color(1, 1, 1).lerp(Color(3, 3, 3), flash / 0.1)
	else:
		modulate = Color.WHITE
	if target and is_instance_valid(target):
		var to_t := target.global_position - global_position
		velocity = to_t.normalized() * speed
		if contact_cd <= 0.0 and to_t.length() < 22.0 and target.has_method("take_damage"):
			contact_cd = 0.9
			target.take_damage(1)
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	for o in get_tree().get_nodes_in_group("enemy"):
		if o == self or not is_instance_valid(o):
			continue
		var d: Vector2 = global_position - o.global_position
		var l := d.length()
		if l > 0.01 and l < 24.0:
			global_position += d / l * (24.0 - l) * 0.5
	position.x = clampf(position.x, bounds.position.x + 14.0, bounds.end.x - 14.0)
	position.y = clampf(position.y, bounds.position.y + 14.0, bounds.end.y - 14.0)
	rotation = velocity.angle() + PI * 0.25
	for b in get_tree().get_nodes_in_group("bullets"):
		if b.global_position.distance_to(global_position) < 15.0:
			hp -= 1
			flash = 0.1
			Global.shake = 2.0
			b.queue_free()
			if hp <= 0:
				die()
			return
	queue_redraw()

func die() -> void:
	Global.add_score(points)
	Global.shake = 3.0
	get_tree().call_group("fx", "burst", global_position, Palette.DANGER, 10)
	queue_free()

func _draw() -> void:
	var pts := PackedVector2Array([Vector2(0, -15), Vector2(15, 0), Vector2(0, 15), Vector2(-15, 0)])
	draw_colored_polygon(pts, Palette.DANGER)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(8, 0), Vector2(0, 8), Vector2(-8, 0)]), Color(0, 0, 0, 0.35))
