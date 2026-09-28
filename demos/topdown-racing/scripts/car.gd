extends CharacterBody2D
class_name Car

signal lap_completed(lap: int, lap_time: float)
signal race_finished(total_time: float)

const ACCEL := 900.0
const BRAKE := 1400.0
const REVERSE := 400.0
const MAX_SPEED := 780.0
const FRICTION := 1.6
const STEER_SPEED := 2.9
const STEER_FALLOFF := 0.35
const DRIFT_GRIP := 0.86
const GRIP := 6.0

@export var body_color := Color(0.9, 0.25, 0.2)
@export var is_ai := false
@export var max_laps := 3
@export var car_name := "ARABA"

var throttle_input := 0.0
var steer_input := 0.0
var lap := 0
var progress := 0.0
var lap_time := 0.0
var total_time := 0.0
var has_finished := false
var speed := 0.0
var running := true

var _prev_progress := 0.0
var _target_idx := 0

@onready var sprite: Node2D = $Body

func _ready() -> void:
	progress = _calc_progress(global_position)
	_prev_progress = progress
	sprite.set("body_color", body_color)

func refresh_visual() -> void:
	sprite.set("body_color", body_color)

func _physics_process(delta: float) -> void:
	if not running:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return
	lap_time += delta
	total_time += delta
	if is_ai:
		_drive_ai(delta)
	else:
		var hb := Input.is_action_pressed("car_handbrake")
		throttle_input = Input.get_action_strength("car_accelerate") - Input.get_action_strength("car_brake")
		steer_input = Input.get_action_strength("car_right") - Input.get_action_strength("car_left")
		_drive(delta, throttle_input, steer_input, hb)
	_update_progress()

func _drive(delta: float, throttle: float, steer: float, handbrake: bool) -> void:
	var forward := Vector2.RIGHT.rotated(global_rotation)
	var right := forward.orthogonal()
	var fwd_speed := velocity.dot(forward)

	if throttle > 0.01:
		velocity += forward * ACCEL * throttle * delta
	elif throttle < -0.01:
		if fwd_speed > 5.0:
			velocity += forward * BRAKE * throttle * delta
		else:
			velocity += forward * REVERSE * throttle * delta

	var lateral := velocity.dot(right)
	var grip := DRIFT_GRIP if handbrake else GRIP
	velocity -= right * lateral * clampf(grip * delta, 0.0, 1.0)
	velocity -= forward * fwd_speed * FRICTION * delta
	velocity = velocity.limit_length(MAX_SPEED)

	var falloff := 1.0 - clampf(absf(fwd_speed) / MAX_SPEED, 0.0, 1.0) * STEER_FALLOFF
	if absf(steer) > 0.01:
		var dir := steer
		if fwd_speed < -1.0:
			dir = -steer
		var turn := STEER_SPEED * falloff * clampf(absf(fwd_speed) / 120.0, 0.0, 1.0)
		global_rotation += dir * turn * delta

	move_and_slide()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is Node and (c.get_collider() as Node).name == "Walls":
			var n: Vector2 = c.get_normal()
			velocity = velocity.slide(n) * 0.92
			velocity -= n * maxf(0.0, -velocity.dot(n)) * 0.3
	speed = velocity.length()

func _drive_ai(delta: float) -> void:
	var track := get_parent().get_node_or_null("Track") as RaceTrack
	if track == null or track.checkpoints.is_empty():
		return
	var best := _target_idx
	var best_d := INF
	for k in 4:
		var idx := (_target_idx + k) % track.checkpoints.size()
		var d := global_position.distance_squared_to(track.checkpoints[idx])
		if d < best_d:
			best_d = d
			best = idx
	_target_idx = best
	var cur := track.checkpoints[_target_idx]
	var nxt := track.checkpoints[(_target_idx + 1) % track.checkpoints.size()]
	var look := cur + (nxt - cur).normalized() * 150.0
	var diff := wrapf((look - global_position).angle() - global_rotation, -PI, PI)
	var steer := clampf(diff * 2.2, -1.0, 1.0)
	var spd := velocity.length()
	var throttle := 1.0
	if absf(diff) > 0.9:
		throttle = 0.25
	elif spd >= MAX_SPEED * 0.95:
		throttle = 0.0
	var hb := absf(diff) > 0.45 and spd > MAX_SPEED * 0.6
	_drive(delta, throttle, steer, hb)

func _update_progress() -> void:
	var p := _calc_progress(global_position)
	if _prev_progress > 0.75 and p < 0.25:
		lap += 1
		lap_completed.emit(lap, lap_time)
		lap_time = 0.0
		if lap >= max_laps:
			has_finished = true
			running = false
			race_finished.emit(total_time)
	_prev_progress = p
	progress = p

func _calc_progress(pos: Vector2) -> float:
	return fposmod(atan2(pos.y / RaceTrack.RY, pos.x / RaceTrack.RX), TAU) / TAU
