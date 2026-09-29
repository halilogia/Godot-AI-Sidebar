extends CharacterBody2D
class_name Car

const ACCEL := 900.0
const BRAKE := 1400.0
const MAX_SPEED := 720.0
const OFFROAD_FACTOR := 0.45
const STEER := 2.4

var color := Palette.PRIMARY
var is_player := false
var ai_target_index := 0
var speed := 0.0
var lap := 0
var last_t := 0.0
var progress := 0.0
var place := 1
var finished := false

func _physics_process(delta: float) -> void:
	var dir := 0.0
	if is_player:
		dir = Input.get_axis(&"steer_left", &"steer_right")
		var th := Input.get_axis(&"brake", &"accelerate")
		_drive(th, dir, delta)
	else:
		_ai(delta)
	velocity = velocity.lerp(Vector2.ZERO, clamp(0.6 * delta, 0.0, 1.0) * (0.0 if speed > 20.0 else 1.0))
	move_and_slide()
	queue_redraw()

func _drive(throttle: float, steer: float, delta: float) -> void:
	var on_road := is_on_road()
	var top := MAX_SPEED * (1.0 if on_road else OFFROAD_FACTOR)
	if throttle > 0.0:
		speed = move_toward(speed, top * throttle, ACCEL * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, 0.0, BRAKE * delta)
	else:
		speed = move_toward(speed, 0.0, 300.0 * delta)
	speed = min(speed, top)
	rotation += steer * STEER * (speed / MAX_SPEED) * delta * signf(speed)
	velocity = Vector2.RIGHT.rotated(rotation) * speed
	speed = velocity.length()
	if not on_road:
		speed = move_toward(speed, 0.0, 200.0 * delta)
		velocity = Vector2.RIGHT.rotated(rotation) * speed

func _ai(delta: float) -> void:
	# steer toward a point ahead on the racing line
	var look := (global_position + Vector2.RIGHT.rotated(rotation) * 200.0)
	var t := fposmod(atan2(look.y / 470.0, look.x / 760.0) / TAU, 1.0)
	var target := Track.outer(t).lerp(Track.inner(t), 0.35)
	var to := (target - global_position).angle()
	var diff := wrapf(to - rotation, -PI, PI)
	_drive(1.0, clamp(diff * 2.0, -1.0, 1.0), delta)

func is_on_road() -> bool:
	var e := Vector2(global_position.x / 760.0, global_position.y / 470.0).length()
	return e < 1.0 and e > 0.52

func _draw() -> void:
	# shadow
	draw_set_transform(Vector2(3, 5), rotation, Vector2.ONE)
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, rotation, Vector2.ONE)
	# body
	var body := PackedVector2Array([Vector2(26, 0), Vector2(-14, -15), Vector2(-6, 0), Vector2(-14, 15)])
	draw_colored_polygon(body, color)
	# cockpit
	draw_circle(Vector2(2, 0), 9.0, Palette.SURFACE)
	draw_line(Vector2(8, -12), Vector2(20, -9), Palette.TEXT, 3.0)
	draw_line(Vector2(8, 12), Vector2(20, 9), Palette.TEXT, 3.0)
	# neon glow ring
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 24, color.lightened(0.4), 2.0, true)
