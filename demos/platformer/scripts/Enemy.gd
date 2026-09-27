class_name Enemy
extends CharacterBody2D

const SPEED := 70.0
const GRAVITY := 1200.0

var is_dead: bool = false

var _dir: float = 1.0

@onready var _visual: Polygon2D = $Visual
@onready var _eye: Polygon2D = $Eye
@onready var _ledge: RayCast2D = $LedgeCheck
@onready var _collider: CollisionShape2D = $Collision


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	velocity.x = _dir * SPEED
	move_and_slide()

	if is_on_wall():
		_flip()
	elif is_on_floor() and not _ledge.is_colliding():
		_flip()


func _flip() -> void:
	_dir = -_dir
	_ledge.position.x = 12.0 * _dir
	_eye.position.x = 3.0 * _dir


func stomp() -> void:
	if is_dead:
		return
	is_dead = true
	_collider.set_deferred(&"disabled", true)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_visual, "rotation", deg_to_rad(90.0) * _dir, 0.25)
	tween.tween_property(_visual, "modulate:a", 0.0, 0.25)
	tween.finished.connect(queue_free)
