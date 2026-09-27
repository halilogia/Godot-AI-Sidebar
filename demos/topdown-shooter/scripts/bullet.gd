class_name Bullet
extends Area2D

## Player atesi. Yon, spawn edildikten sonra `direction` ile verilir.

@export var speed: float = 720.0
@export var damage: int = 1
@export var lifetime: float = 1.4

var direction: Vector2 = Vector2.RIGHT

var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	# Enemy sinifi bilinmeden: grup + method uzerinden coz.
	if not body.is_in_group("enemies") or not body.has_method("take_damage"):
		return
	body.call("take_damage", damage)
	queue_free()
