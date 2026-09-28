class_name Collectible
extends Area3D

signal collected(total: int)

@onready var mesh: MeshInstance3D = $MeshInstance3D

var _t := 0.0
var _active := true


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	mesh.rotate_y(delta * 1.6)
	mesh.position.y = sin(_t * 2.2) * 0.15


func _on_body_entered(body: Node3D) -> void:
	if not _active or not body is Player:
		return
	_active = false
	set_deferred("monitoring", false)
	mesh.visible = false
	var total: int = GameState.collect()
	collected.emit(total)
