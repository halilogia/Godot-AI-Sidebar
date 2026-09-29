class_name Player
extends CharacterBody2D

const SPEED := 320.0
const RADIUS := 18.0
const ACCENT_CLAMP := 18.0

var aim := Vector2.RIGHT
var fire_cooldown := 0.0
const FIRE_RATE := 0.16

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).limit_length(1.0)
	velocity = dir * SPEED
	move_and_slide()
	position.x = clamp(position.x, RADIUS + 4.0, 1276.0)
	position.y = clamp(position.y, RADIUS + 4.0, 716.0)
	fire_cooldown = max(0.0, fire_cooldown - delta)

func aim_at(target: Vector2) -> void:
	aim = (target - global_position).normalized()

func can_fire() -> bool:
	return fire_cooldown <= 0.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, RADIUS - 2.0, Palette.PRIMARY)
	draw_circle(Vector2.ZERO + aim * 10.0, 6.0, Palette.ACCENT)
	draw_arc(Vector2.ZERO, RADIUS + 5.0, 0, TAU, 32, Color(Palette.PRIMARY, 0.35), 2.0)
