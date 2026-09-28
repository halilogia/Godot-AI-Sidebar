extends Node2D
class_name Walker

const SPEED := 70.0
const GRAVITY := 1400.0
var dir := 1
var alive := true
var body: CharacterBody2D

func _ready() -> void:
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if not alive:
		return
	body.velocity.y += GRAVITY * delta
	body.velocity.x = dir * SPEED
	body.move_and_slide()
	if body.is_on_wall():
		dir = -dir
	if global_position.y > 2000.0:
		alive = false
		queue_free()

func _draw() -> void:
	if not alive:
		return
	draw_circle(Vector2(0, -2), 16.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2(0, -2), 15.0, Palette.DANGER)
	# eyes look in travel direction
	draw_circle(Vector2(dir * 5.0, -5.0), 3.0, Palette.BG_DEEP)
	draw_rect(Rect2(-9.0, 6.0, 6.0, 8.0), Color(Palette.DANGER.r, Palette.DANGER.g, Palette.DANGER.b, 0.6), true)
	draw_rect(Rect2(3.0, 6.0, 6.0, 8.0), Color(Palette.DANGER.r, Palette.DANGER.g, Palette.DANGER.b, 0.6), true)
