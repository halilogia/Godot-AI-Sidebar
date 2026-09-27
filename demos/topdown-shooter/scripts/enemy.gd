class_name Enemy
extends CharacterBody2D

## Oyuncuya dogru yuruyen, temas edince hasar veren dusman.

signal died(enemy: Node2D, points: int)

@export var speed: float = 110.0
@export var max_health: int = 3
@export var points: int = 10
@export var contact_damage: int = 9

var health: int = 0

var _dead: bool = false
var _target: Node2D

@onready var _body: Polygon2D = $Body


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_target = get_tree().get_first_node_in_group("player")
	$HurtBox.body_entered.connect(_on_hurtbox_body_entered)


func _physics_process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		velocity = Vector2.ZERO
		return
	var to_target := _target.global_position - global_position
	if to_target.length_squared() < 4.0:
		velocity = Vector2.ZERO
	else:
		velocity = to_target.normalized() * speed
	move_and_slide()


func take_damage(amount: int) -> void:
	if _dead:
		return
	health -= amount
	_flash()
	if health > 0:
		return
	_dead = true
	died.emit(self, points)
	queue_free()


func _flash() -> void:
	_body.modulate = Color(1.0, 0.45, 0.45)
	var tween := create_tween()
	tween.tween_property(_body, "modulate", Color(1, 1, 1), 0.12)


func _on_hurtbox_body_entered(body: Node2D) -> void:
	# Player sinifi bilinmeden: grup + method uzerinden coz.
	if not body.is_in_group("player") or not body.has_method("take_damage"):
		return
	body.call("take_damage", contact_damage)
