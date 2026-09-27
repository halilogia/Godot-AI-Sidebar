class_name Player
extends CharacterBody2D

signal died
signal health_changed(health: int)
signal score_changed(score: int)

const MAX_HEALTH := 3
const SPEED := 230.0
const GROUND_ACCEL := 2400.0
const AIR_ACCEL := 1500.0
const GROUND_FRICTION := 2800.0
const JUMP_VELOCITY := -440.0
const JUMP_CUT := 2.4
const GRAVITY := 1300.0
const FALL_GRAVITY := 1.5
const MAX_FALL_SPEED := 1000.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const INVULN_TIME := 0.9
const STOMP_BOUNCE := -340.0

var health: int = MAX_HEALTH
var score: int = 0
var control_enabled: bool = true

var _coyote: float = 0.0
var _buffer: float = 0.0
var _invuln: float = 0.0

@onready var _visual: Polygon2D = $Visual
@onready var _face: Polygon2D = $Face
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _camera: ShakeCamera = $Camera


func _ready() -> void:
	_invuln = 0.5


func _process(_delta: float) -> void:
	if _invuln > 0.0:
		_visual.modulate.a = 0.35 if fmod(_invuln, 0.2) < 0.1 else 1.0
	else:
		_visual.modulate.a = 1.0
	var stretch: float = clampf(absf(velocity.y) / 1400.0, 0.0, 0.18)
	_visual.scale = Vector2(1.0 - stretch * 0.6, 1.0 + stretch)


func _physics_process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)

	var dir: float = 0.0
	if control_enabled:
		dir = Input.get_axis(&"move_left", &"move_right")
		_buffer = JUMP_BUFFER if Input.is_action_just_pressed(&"jump") else maxf(0.0, _buffer - delta)
	else:
		_buffer = 0.0

	var on_floor: bool = is_on_floor()
	if on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - delta)

	var accel: float = GROUND_ACCEL if on_floor else AIR_ACCEL
	if absf(dir) > 0.01:
		velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)
		_face.position.x = 3.0 * signf(dir)
	elif on_floor:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)

	if control_enabled and _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0

	var g: float = GRAVITY
	if velocity.y > 0.0:
		g *= FALL_GRAVITY
	elif not Input.is_action_pressed(&"jump"):
		g *= JUMP_CUT
	velocity.y = minf(velocity.y + g * delta, MAX_FALL_SPEED)

	move_and_slide()
	_check_contacts()


func _check_contacts() -> void:
	for body in _hurtbox.get_overlapping_bodies():
		if not (body is Enemy) or body.is_dead:
			continue
		var stomping: bool = velocity.y > 60.0 and global_position.y <= body.global_position.y + 10.0
		if stomping:
			body.stomp()
			velocity.y = STOMP_BOUNCE
			add_score(100)
		else:
			take_damage(body.global_position)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func take_damage(from_global: Vector2) -> void:
	if _invuln > 0.0 or not control_enabled:
		return
	health -= 1
	health_changed.emit(health)
	_invuln = INVULN_TIME
	var away: Vector2 = global_position - from_global
	if away.length() < 1.0:
		away = Vector2(1.0, -1.0)
	away.y = minf(away.y, -1.0)
	velocity = away.normalized() * Vector2(240.0, 300.0)
	_camera.add_shake(7.0)
	if health <= 0:
		control_enabled = false
		_visual.modulate = Color(0.75, 0.15, 0.15)
		died.emit()
