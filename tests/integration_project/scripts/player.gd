extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		
	move_and_slide()
