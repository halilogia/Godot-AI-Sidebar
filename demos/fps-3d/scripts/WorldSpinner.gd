extends Node3D

@onready var mesh: MeshInstance3D = $MeshInstance3D

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	rotate_y(delta * 0.4)
