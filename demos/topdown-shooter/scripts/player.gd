class_name Player
extends CharacterBody2D

## WASD ile hareket, fareye nisan, sol tik ile ates.

signal health_changed(current: int, maximum: int)
signal died

@export var speed: float = 285.0
@export var max_health: int = 100
@export var fire_interval: float = 0.16
@export var invulnerability_time: float = 0.7
@export var bullet_scene: PackedScene

var health: int = 0
var alive: bool = true

var _fire_timer: float = 0.0
var _invuln_timer: float = 0.0

@onready var _body: Polygon2D = $Body
@onready var _muzzle: Node2D = $Muzzle


func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	_tick_invulnerability(delta)
	if not alive:
		return

	velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * speed
	move_and_slide()
	_aim_at_mouse()

	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0:
		shoot()


func _aim_at_mouse() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 1.0:
		rotation = to_mouse.angle()


func shoot() -> void:
	_fire_timer = fire_interval
	var container := get_tree().get_first_node_in_group("bullets")
	if container == null or bullet_scene == null:
		return
	var bullet := bullet_scene.instantiate()
	bullet.set("direction", Vector2.RIGHT.rotated(rotation))
	container.add_child(bullet)
	bullet.global_position = _muzzle.global_position


func take_damage(amount: int) -> void:
	if not alive or _invuln_timer > 0.0:
		return
	health = maxi(health - amount, 0)
	_invuln_timer = invulnerability_time
	health_changed.emit(health, max_health)
	if health <= 0:
		alive = false
		velocity = Vector2.ZERO
		died.emit()


func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func _tick_invulnerability(delta: float) -> void:
	if _invuln_timer <= 0.0:
		_body.modulate.a = 1.0
		return
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	# Yanip sonme ile dokunulmazlik gostergesi.
	_body.modulate.a = 0.35 + 0.65 * absf(sin(_invuln_timer * 28.0))
