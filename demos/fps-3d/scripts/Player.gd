class_name Player
extends CharacterBody3D

const SPEED := 5.0
const ACCEL := 60.0
const JUMP := 5.0
const MOUSE_SENS := 0.0022

@onready var head: Node3D = $Head

var yaw := 0.0
var pitch := 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		yaw -= m.relative.x * MOUSE_SENS
		pitch = clampf(pitch - m.relative.y * MOUSE_SENS, -1.3, 1.3)
		rotation.y = yaw
		head.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 9.8 * delta

	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if input.length() > 1.0:
		input = input.normalized()
	var dir := transform.basis * Vector3(input.x, 0.0, input.y)
	var target := dir.limit_length(1.0) * SPEED
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)

	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = JUMP
	move_and_slide()
