class_name Enemy
extends CharacterBody2D

signal died(enemy: Node, at: Vector2)

var speed := 105.0
var hp := 3
var target: Node2D
var flash := 0.0

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		var dir := (target.global_position - global_position).normalized()
		velocity = dir * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	flash = max(0.0, flash - delta)

func take_damage(amount: int, at: Vector2) -> void:
	hp -= amount
	flash = 0.12
	if hp <= 0:
		died.emit(self, at)
		queue_free()

func _draw() -> void:
	var c := Palette.DANGER if flash <= 0.0 else Color.WHITE
	draw_circle(Vector2.ZERO, 18.0, Color(0, 0, 0, 0.35))
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		pts.append(Vector2(cos(a), sin(a)) * 16.0)
	draw_colored_polygon(pts, c)
	draw_circle(Vector2.ZERO, 7.0, c.darkened(0.45))
