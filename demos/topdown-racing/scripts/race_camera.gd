extends Camera2D

@export var lead := 190.0
@export var follow_path: NodePath

var target: Node2D
var shake := 0.0

func _ready() -> void:
	make_current()
	if follow_path != NodePath():
		target = get_node_or_null(follow_path) as Node2D

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var car := target as Car
	var fwd := Vector2.RIGHT.rotated(target.global_rotation)
	global_position = target.global_position + fwd * lead
	var z := 1.0
	if car != null:
		z = clampf(1.6 - car.speed / 900.0, 1.15, 1.6)
	zoom = Vector2(z, z)
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 3.0)
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 10.0
	else:
		offset = offset.lerp(Vector2.ZERO, 0.3)
