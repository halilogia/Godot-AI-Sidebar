class_name ShakeCamera
extends Camera2D

@export var shake_strength: float = 6.0
@export var shake_decay: float = 6.0

var _shake: float = 0.0


func _process(delta: float) -> void:
	if _shake > 0.01:
		_shake = maxf(0.0, _shake - shake_decay * _shake * delta)
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * shake_strength
	elif offset != Vector2.ZERO:
		_shake = 0.0
		offset = offset.lerp(Vector2.ZERO, clampf(delta * 12.0, 0.0, 1.0))


func add_shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 1.5)
