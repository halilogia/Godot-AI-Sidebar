class_name Collectible
extends Area3D

signal collected(value: int)

@export var value: int = 1
var _t := 0.0
@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	mesh.rotate_y(delta * 1.4)
	mesh.position.y = sin(_t * 2.0) * 0.08

func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		collected.emit(value)
		queue_free()
