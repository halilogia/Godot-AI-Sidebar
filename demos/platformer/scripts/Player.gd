class_name Player
extends CharacterBody2D

signal died
signal score_changed(score: int)

const SPEED := 260.0
const ACCEL := 2200.0
const FRICTION := 2600.0
const JUMP_VELOCITY := -620.0
const COYOTE := 0.10
const BUFFER := 0.12

var coins := 0
var camera: Camera2D
var lives := 3
var _coyote := 0.0
var _buffer := 0.0
var _squash := 0.0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 8.0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 30)
	cs.shape = rect
	cs.position = Vector2(0, -15)
	add_child(cs)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.limit_left = 0
	cam.limit_right = Level.W * Palette.TILE
	cam.limit_top = 0
	cam.limit_bottom = Level.H * Palette.TILE
	cam.limit_smoothed = true
	add_child(cam)
	camera = cam
	cam.make_current()

func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if absf(dir) > 0.05:
		velocity.x = move_toward(velocity.x, dir * SPEED, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	if is_on_floor():
		_coyote = COYOTE
		_squash = 0.0
	else:
		_coyote -= delta
		_squash = minf(1.0, _squash + delta * 4.0)

	if Input.is_action_just_pressed("jump"):
		_buffer = BUFFER
	else:
		_buffer -= delta

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_squash = 1.0

	if not Input.is_action_pressed("jump") and velocity.y < 0.0:
		velocity.y += 1400.0 * delta

	velocity.y += 1500.0 * delta
	move_and_slide()

	if global_position.y > 2000.0:
		_die()

func collect() -> void:
	coins += 1
	score_changed.emit(coins)

func _die() -> void:
	lives -= 1
	died.emit()

func _draw() -> void:
	var s := 22.0
	var w := 22.0 * (1.0 + 0.18 * _squash)
	var h := 30.0 * (1.0 - 0.18 * _squash)
	var rect := Rect2(-w * 0.5, -h, w, h)
	# shadow
	draw_circle(Vector2(0, 2), 12.0, Color(0, 0, 0, 0.35))
	# body glow
	draw_rect(rect.grow(6.0), Color(Palette.PRIMARY.r, Palette.PRIMARY.g, Palette.PRIMARY.b, 0.25), true)
	draw_rect(rect, Palette.PRIMARY, true)
	# visor
	draw_rect(Rect2(-w * 0.5 + 4.0, -h + 5.0, w - 8.0, 7.0), Palette.BG_DEEP, true)
	# feet
	draw_rect(Rect2(-w * 0.5 + 2.0, -5.0, 7.0, 5.0), Palette.SURFACE, true)
	draw_rect(Rect2(w * 0.5 - 9.0, -5.0, 7.0, 5.0), Palette.SURFACE, true)
