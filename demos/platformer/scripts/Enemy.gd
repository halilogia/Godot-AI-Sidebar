extends Area2D

@export var patrol_distance: float = 80.0
@export var patrol_speed: float = 70.0

var start_x: float = 0.0
var direction: float = 1.0

@onready var visual: Node2D = $Visual

func _ready() -> void:
	start_x = position.x
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position.x += direction * patrol_speed * delta

	if abs(position.x - start_x) >= patrol_distance:
		direction *= -1.0
		position.x = start_x + (direction * patrol_distance)
		if visual:
			visual.scale.x = direction

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		GameState.trigger_player_death()
