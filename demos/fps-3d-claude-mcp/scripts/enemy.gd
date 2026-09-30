class_name Enemy
extends CharacterBody3D
## Düşman: oyuncuyu ancak görüş çizgisi (raycast) açıkken görür, görürse kovalar ve ateş eder; görmezse son bilinen konuma gider.

const SPEED := 3.4
const SIGHT_RANGE := 34.0
const FIRE_RANGE := 26.0
const GRAVITY := 15.0
const MAX_HP := 60.0

var hp := MAX_HP
var player: Player
var last_seen := Vector3.ZERO
var has_last_seen := false
var fire_cooldown := 3.0
var walk_phase := 0.0
var dead := false
var wander_target := Vector3.ZERO
var wander_wait := 0.0

var body_root: Node3D
var arm_l: MeshInstance3D
var arm_r: MeshInstance3D
var leg_l: MeshInstance3D
var leg_r: MeshInstance3D
var flash_mat: StandardMaterial3D
var has_model := false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.9
	add_child(cs)
	body_root = Node3D.new()
	add_child(body_root)
	var scene := load("res://assets/models/soldier.glb") as PackedScene
	if scene != null:
		var model := scene.instantiate() as Node3D
		model.rotation.y = PI   # modelin önü Blender +Y (glTF -Z): oyuncuya bakış -Z ile aynı; ters ise çevir
		body_root.add_child(model)
		has_model = true
	else:
		_build_model()
	wander_target = global_position

func _build_model() -> void:
	var cloth := Color(0.34, 0.36, 0.28)
	var dark := Color(0.16, 0.17, 0.14)
	var skin := Color(0.82, 0.62, 0.5)
	flash_mat = _mat(cloth)
	body_root.add_child(_part(Vector3(0.5, 0.62, 0.28), Vector3(0, 1.15, 0), flash_mat))
	body_root.add_child(_part(Vector3(0.22, 0.22, 0.22), Vector3(0, 1.62, 0), _mat(skin)))
	var helmet := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.16
	hs.height = 0.24
	helmet.mesh = hs
	helmet.position = Vector3(0, 1.72, 0)
	helmet.material_override = _mat(Color(0.28, 0.3, 0.25))
	body_root.add_child(helmet)
	leg_l = _part(Vector3(0.18, 0.7, 0.2), Vector3(-0.14, 0.35, 0), _mat(dark))
	leg_r = _part(Vector3(0.18, 0.7, 0.2), Vector3(0.14, 0.35, 0), _mat(dark))
	arm_l = _part(Vector3(0.14, 0.55, 0.16), Vector3(-0.34, 1.15, 0), _mat(cloth.darkened(0.15)))
	arm_r = _part(Vector3(0.14, 0.55, 0.16), Vector3(0.34, 1.15, 0), _mat(cloth.darkened(0.15)))
	for m: MeshInstance3D in [leg_l, leg_r, arm_l, arm_r]:
		body_root.add_child(m)
	var gun := _part(Vector3(0.06, 0.08, 0.6), Vector3(0.3, 1.1, -0.34), _mat(Color(0.1, 0.1, 0.11)))
	body_root.add_child(gun)

func _part(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = mat
	return m

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat

func has_line_of_sight() -> bool:
	if player == null or player.dead:
		return false
	var eye := global_position + Vector3(0, 1.6, 0)
	var target := player.global_position + Vector3(0, 1.3, 0)
	if eye.distance_to(target) > SIGHT_RANGE:
		return false
	# görüş konisi: yalnızca önüne bakabilir
	var to_target := (target - eye).normalized()
	var forward := -global_transform.basis.z
	if forward.dot(to_target) < -0.2 and not has_last_seen:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, target)
	q.exclude = [get_rid()]
	q.collision_mask = 1 | 2
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit["collider"] == player

func _physics_process(delta: float) -> void:
	if dead:
		return
	velocity.y = velocity.y - GRAVITY * delta if not is_on_floor() else 0.0
	var move_dir := Vector3.ZERO
	var sees := has_line_of_sight()
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if sees:
		last_seen = player.global_position
		has_last_seen = true
		var to_p := player.global_position - global_position
		to_p.y = 0.0
		_face(to_p, delta, 8.0)
		if to_p.length() > 9.0:
			move_dir = to_p.normalized()
		if to_p.length() < FIRE_RANGE and fire_cooldown <= 0.0:
			_shoot()
	elif has_last_seen:
		var to_l := last_seen - global_position
		to_l.y = 0.0
		if to_l.length() > 1.5:
			move_dir = to_l.normalized()
			_face(to_l, delta, 5.0)
		else:
			has_last_seen = false
	else:
		wander_wait -= delta
		var to_w := wander_target - global_position
		to_w.y = 0.0
		if to_w.length() < 1.0 or wander_wait <= 0.0:
			wander_target = global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
			wander_wait = randf_range(3.0, 6.0)
		else:
			move_dir = to_w.normalized() * 0.5
			_face(to_w, delta, 3.0)
	var spd := SPEED * (1.0 if sees else 0.85)
	velocity.x = move_toward(velocity.x, move_dir.x * spd, 20.0 * delta)
	velocity.z = move_toward(velocity.z, move_dir.z * spd, 20.0 * delta)
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length())

func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() < 0.01:
		return
	var target := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target, minf(1.0, rate * delta))

func _animate(delta: float, speed: float) -> void:
	walk_phase += delta * speed * 2.6
	if has_model:
		var k := clampf(speed / SPEED, 0.0, 1.0)
		body_root.position.y = absf(sin(walk_phase)) * 0.06 * k
		body_root.rotation.z = sin(walk_phase) * 0.07 * k
		return
	var swing := sin(walk_phase) * 0.7 * clampf(speed / SPEED, 0.0, 1.0)
	leg_l.rotation.x = swing
	leg_r.rotation.x = -swing
	arm_l.rotation.x = -swing * 0.8
	arm_r.rotation.x = -0.9 if fire_cooldown > 0.0 and has_last_seen else swing * 0.8
	body_root.position.y = absf(sin(walk_phase)) * 0.04 * clampf(speed / SPEED, 0.0, 1.0)

func _shoot() -> void:
	fire_cooldown = randf_range(1.4, 2.6)
	var dist := global_position.distance_to(player.global_position)
	var chance := clampf(0.75 - dist * 0.02, 0.15, 0.7)
	if randf() < chance:
		player.take_damage(randf_range(3.0, 7.0))

func take_damage(amount: float, _pos: Vector3 = Vector3.ZERO) -> bool:
	if dead:
		return false
	hp -= amount
	last_seen = player.global_position if player else last_seen
	has_last_seen = true
	if flash_mat != null:
		flash_mat.albedo_color = Color(1.0, 0.3, 0.25)
		get_tree().create_timer(0.08).timeout.connect(func() -> void:
			if is_instance_valid(self) and not dead:
				flash_mat.albedo_color = Color(0.34, 0.36, 0.28))
	elif body_root != null:
		body_root.scale = Vector3(1.08, 0.94, 1.08)
		get_tree().create_timer(0.08).timeout.connect(func() -> void:
			if is_instance_valid(self) and not dead:
				body_root.scale = Vector3.ONE)
	if hp <= 0.0:
		_die()
		return true
	return false

func _die() -> void:
	dead = true
	collision_layer = 0
	collision_mask = 0
	var tw := create_tween()
	tw.tween_property(body_root, "rotation:x", -PI * 0.5, 0.5)
	tw.tween_interval(4.0)
	tw.tween_callback(queue_free)
