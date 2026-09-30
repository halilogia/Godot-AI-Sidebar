class_name Enemy
extends CharacterBody3D

## Temel düşman: görüş çizgisi varsa yaklaşır, menzile girince durup ateş eder.
## Duvar arkasına geçen oyuncuyu göremez; tıkanırsa yana kaçar.

signal died(enemy: Enemy)

const GRAVITY := 22.0
const MOVE_SPEED := 3.4
const SIGHT_RANGE := 42.0
const ATTACK_RANGE := 26.0
const FIRE_INTERVAL := 1.1
const ACCURACY := 0.06
const EYE_HEIGHT := 1.62
const STEP_FREQ := 5.4
const BODY_BOB := 0.055

@export var health: float = 60.0
@export var max_health: float = 60.0

var _target: Node3D = null
var _fire_timer: float = 0.0
var _gravity: float = GRAVITY
var _dead: bool = false
var _stuck: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _walk_time: float = 0.0
var _walk_amount: float = 0.0

@onready var _body: MeshInstance3D = $Body
@onready var _head: MeshInstance3D = $Head
@onready var _muzzle: Marker3D = $Muzzle
@onready var _barrel: MeshInstance3D = $Barrel


func _ready() -> void:
	_last_pos = global_position


func setup(target: Node3D) -> void:
	_target = target


func take_hit(_from: Vector3, _headshot: bool) -> void:
	if _dead:
		return
	health -= 20.0
	_body.scale.y = 1.0 - 0.25 * (1.0 - health / max_health)
	if health <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	died.emit(self)
	queue_free()


func _physics_process(delta: float) -> void:
	if _dead or _target == null or not is_instance_valid(_target):
		return

	velocity.y -= _gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	if not is_on_floor():
		move_and_slide()
		return

	var to_target := _target.global_position - global_position
	var dist := to_target.length()
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var dir := flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD

	var sees := dist <= SIGHT_RANGE and _has_line_of_sight()
	if sees:
		_face(dir)
		if dist <= ATTACK_RANGE:
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			velocity.x = dir.x * MOVE_SPEED
			velocity.z = dir.z * MOVE_SPEED
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	_animate_walk(delta)

	# Tıkanıp kalmayı önle.
	if sees and global_position.distance_to(_last_pos) < 0.02:
		_stuck += delta
		if _stuck > 1.2:
			var side := dir.cross(Vector3.UP).normalized() * MOVE_SPEED
			velocity.x = side.x
			velocity.z = side.z
			_stuck = 0.0
	else:
		_stuck = 0.0
	_last_pos = global_position

	if sees:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_timer = FIRE_INTERVAL
			_shoot()


## Yürüme animasyonu: gövde ve kafa adımla birlikte salınır, silah da uyar.
func _animate_walk(delta: float) -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and planar > 0.2
	_walk_amount = move_toward(_walk_amount, 1.0 if moving else 0.0, delta * 6.0)
	if _walk_amount > 0.001:
		_walk_time += delta * (2.0 + planar * 0.9)
	var phase := _walk_time * STEP_FREQ
	var s := sin(phase)
	var c := cos(phase)
	var a := _walk_amount

	_body.position.y = 0.9 + absf(s) * BODY_BOB * a
	_body.rotation.x = s * 0.1 * a
	_body.rotation.z = c * 0.05 * a
	_head.position.y = EYE_HEIGHT + absf(s) * BODY_BOB * 0.8 * a
	_head.rotation.x = -s * 0.06 * a
	_barrel.position.y = 1.25 + absf(s) * BODY_BOB * 0.5 * a
	_barrel.position.x = 0.16 + c * 0.05 * a
	_barrel.position.z = -0.2 + s * 0.14 * a
	_barrel.rotation.x = s * 0.06 * a


func _face(dir: Vector3) -> void:
	var yaw := atan2(-dir.x, -dir.z)
	rotate_y(angle_difference(rotation.y, yaw))


## Görüş çizgisi: gözden hedefin gövdesine iki ışın atılır; ikisi de engele
## çarpıyorsa düşman oyuncuyu görmüyor demektir.
func _has_line_of_sight() -> bool:
	var space := get_world_3d().direct_space_state
	var origin := _head.global_position
	var points := [
		_target.global_position + Vector3(0.0, 1.2, 0.0),
		_target.global_position + Vector3(0.0, 0.7, 0.0),
	]
	for point: Vector3 in points:
		var query := PhysicsRayQueryParameters3D.create(origin, point)
		query.exclude = [get_rid(), _target.get_rid()]
		if space.intersect_ray(query).is_empty():
			return true
	return false


func _shoot() -> void:
	if not _target.has_method("damage_player"):
		return
	var from := _muzzle.global_position
	var to := _target.global_position + Vector3(0.0, 1.2, 0.0)
	var dir := (to - from).normalized()
	dir = dir.rotated(Vector3.UP, randf_range(-ACCURACY, ACCURACY))
	dir = dir.rotated(Vector3.RIGHT, randf_range(-ACCURACY, ACCURACY))
	var end: Vector3 = from + dir * ATTACK_RANGE
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, end)
	query.exclude = [get_rid(), _target.get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and hit.get("collider") == _target:
		_target.damage_player(9.0)
