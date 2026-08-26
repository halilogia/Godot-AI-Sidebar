extends CharacterBody2D

@export var speed: float = 100.0
@export var patrol_distance: float = 200.0

var start_x: float = 0.0
var direction: int = 1

func _ready() -> void:
	start_x = position.x

func _physics_process(delta: float) -> void:
	if abs(position.x - start_x) > patrol_distance:
		direction *= -1
		
	velocity.x = direction * speed
	move_and_slide()
