class_name Player
extends CharacterBody2D

const SPEED := 340.0
const RADIUS := 14.0
const BULLET_SCENE := preload("res://scripts/Bullet.gd")

var arena_rect := Rect2(0, 0, 800, 500)
var muzzle_t := 0.0
var fire_cooldown := 0.16
var alive := true

@onready var muzzle: Node2D = $Muzzle

var aim_dir := Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RADIUS
	cs.shape = c
	add_child(cs)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")
	velocity = input.limit_length(1.0) * SPEED
	move_and_slide()
	var h := Vector2(arena_rect.size.x * 0.5, 0)
	position.x = clampf(position.x, arena_rect.position.x + RADIUS, arena_rect.position.x + h.x - RADIUS)
	position.y = clampf(position.y, arena_rect.position.y + RADIUS, arena_rect.position.y + arena_rect.size.y - RADIUS)
	if input.length() > 0.1:
		aim_dir = input.normalized()
		rotation = lerp_angle(rotation, aim_dir.angle(), delta * 12.0)
	fire_cooldown -= delta
	muzzle_t = maxf(0.0, muzzle_t - delta)
	if Input.is_action_pressed("shoot") and fire_cooldown <= 0.0:
		fire_cooldown = 0.16
		shoot()
	queue_redraw()

func shoot() -> void:
	var b := BULLET_SCENE.new()
	get_parent().add_child(b)
	var dir := (get_global_mouse_position() - global_position).normalized()
	if Input.get_last_mouse_velocity().length() < 1.0:
		if aim_dir.length() > 0.1:
			dir = aim_dir
		else:
			dir = Vector2.RIGHT.rotated(rotation)
	b.direction = dir
	b.global_position = muzzle.global_position
	muzzle_t = 0.07
	queue_redraw()

func take_damage(amount: int) -> void:
	if not alive:
		return
	Global.game_health = maxi(0, Global.game_health - amount)
	Global.health_changed.emit(Global.game_health)
	Global.damage_flash = 0.1
	Global.shake = 6.0
	if Global.game_health <= 0:
		alive = false
		Global.player_died.emit()

func _draw() -> void:
	var pts := PackedVector2Array([Vector2(20, 0), Vector2(-13, 13), Vector2(-7, 0), Vector2(-13, -13)])
	draw_colored_polygon(pts, Palette.PRIMARY)
	var pts2 := PackedVector2Array([Vector2(20, 0), Vector2(-13, 13), Vector2(-7, 0), Vector2(-13, -13)])
	draw_polyline(pts2 + PackedVector2Array([pts2[0]]), Color(0, 0, 0, 0.35), 3.0)
	if muzzle_t > 0.0:
		draw_circle(Vector2(26, 0), 7.0 * (muzzle_t / 0.07), Palette.ACCENT)
