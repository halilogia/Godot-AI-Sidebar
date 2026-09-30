class_name Player
extends CharacterBody3D
## Birinci şahıs oyuncu: yürüme, koşma (stamina), zıplama, eğilme, nişan alma (ADS), üç silah, şarjör, ölüm / yeniden doğuş.

signal health_changed(hp: float, max_hp: float)
signal stamina_changed(value: float, max_value: float)
signal ammo_changed(clip: int, reserve: int, weapon_name: String)
signal reload_started(duration: float)
signal damaged
signal hit_confirmed(killed: bool)
signal died
signal respawned

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.6
const CROUCH_SPEED := 2.4
const JUMP_SPEED := 5.4
const GRAVITY := 15.0
const MAX_HP := 100.0
const MAX_STAMINA := 100.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const EYE_STAND := 1.62
const EYE_CROUCH := 1.0
const FOV_HIP := 78.0
const FOV_ADS := 52.0
const MOUSE_SENS := 0.0022

var hp: float = MAX_HP
var stamina: float = MAX_STAMINA
var exhausted := false
var crouching := false
var aiming := false
var dead := false
var weapon_index := 0
var clips: Array[int] = []
var reserves: Array[int] = []
var fire_cooldown := 0.0
var reload_left := 0.0
var bob_time := 0.0
var pitch := 0.0
var kick := 0.0
var spawn_position := Vector3.ZERO
var invulnerable_until := 0.0

var head: Node3D
var camera: Camera3D
var viewmodel: Node3D
var collider: CollisionShape3D
var capsule: CapsuleShape3D
var muzzle_light: OmniLight3D
var muzzle_timer := 0.0
var _hip_pos := Vector3(0.2, -0.22, -0.5)
var _ads_pos := Vector3(0.0, -0.14, -0.4)

static func ensure_input_actions() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "crouch": [KEY_C, KEY_CTRL], "reload": [KEY_R],
		"weapon_1": [KEY_1], "weapon_2": [KEY_2], "weapon_3": [KEY_3], "release_mouse": [KEY_ESCAPE],
	}
	for action: String in map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key: int in map[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key as Key
				InputMap.action_add_event(action, ev)
	for pair: Array in [["fire", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var mev := InputEventMouseButton.new()
			mev.button_index = pair[1] as MouseButton
			InputMap.action_add_event(pair[0], mev)

func _ready() -> void:
	ensure_input_actions()
	collision_layer = 2
	collision_mask = 1
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = STAND_HEIGHT
	collider = CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = STAND_HEIGHT * 0.5
	add_child(collider)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_STAND
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = FOV_HIP
	camera.near = 0.03
	camera.far = 400.0
	head.add_child(camera)
	camera.current = true
	viewmodel = Node3D.new()
	viewmodel.name = "Viewmodel"
	viewmodel.position = _hip_pos
	viewmodel.scale = Vector3.ONE * 0.62   # ekran görüntüsünde silah çok büyüktü
	camera.add_child(viewmodel)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.75, 0.4)
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 6.0
	muzzle_light.position = Vector3(0, 0, -0.9)
	viewmodel.add_child(muzzle_light)
	for w: Dictionary in WeaponData.WEAPONS:
		clips.append(int(w["clip"]))
		reserves.append(int(w["reserve"]))
	spawn_position = global_position
	_build_viewmodel()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_emit_all()

func _emit_all() -> void:
	health_changed.emit(hp, MAX_HP)
	stamina_changed.emit(stamina, MAX_STAMINA)
	_emit_ammo()

func _emit_ammo() -> void:
	ammo_changed.emit(clips[weapon_index], reserves[weapon_index], str(WeaponData.get_weapon(weapon_index)["name"]))

# --- girdi ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		rotate_y(-m.relative.x * MOUSE_SENS * (0.6 if aiming else 1.0))
		pitch = clampf(pitch - m.relative.y * MOUSE_SENS * (0.6 if aiming else 1.0), -1.45, 1.45)
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 3:
		if event.is_action_pressed("weapon_%d" % (i + 1)):
			switch_weapon(i)

func switch_weapon(i: int) -> void:
	if i == weapon_index or reload_left > 0.0:
		return
	weapon_index = i
	fire_cooldown = 0.25
	_build_viewmodel()
	_emit_ammo()

# --- fizik ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var on_floor := is_on_floor()
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var want_crouch := Input.is_action_pressed("crouch")
	if crouching and not want_crouch and _blocked_above():
		want_crouch = true
	crouching = want_crouch
	aiming = Input.is_action_pressed("aim") and reload_left <= 0.0
	# koşma: yalnız yerde; havadayken stamina hiç düşmez
	var sprinting := Input.is_action_pressed("sprint") and input_dir.length() > 0.1 and on_floor and not crouching and not aiming and not exhausted and stamina > 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - 24.0 * delta)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(MAX_STAMINA, stamina + (12.0 if input_dir.length() > 0.1 else 20.0) * delta)
		if exhausted and stamina >= 30.0:
			exhausted = false
	stamina_changed.emit(stamina, MAX_STAMINA)
	var speed := CROUCH_SPEED if crouching else (SPRINT_SPEED if sprinting else WALK_SPEED)
	if aiming:
		speed *= 0.6
	var accel := 14.0 if on_floor else 3.0
	velocity.x = move_toward(velocity.x, wish.x * speed, accel * delta * speed)
	velocity.z = move_toward(velocity.z, wish.z * speed, accel * delta * speed)
	if on_floor:
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump") and not crouching:
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if global_position.y < -30.0:
		take_damage(9999.0)
	_update_body_height(delta)
	_update_camera(delta, on_floor, sprinting)
	_update_weapon(delta)

func _blocked_above() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, CROUCH_HEIGHT, 0), global_position + Vector3(0, STAND_HEIGHT + 0.1, 0))
	q.exclude = [get_rid()]
	q.collision_mask = 1
	return not space.intersect_ray(q).is_empty()

func _update_body_height(delta: float) -> void:
	var target_h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	capsule.height = lerpf(capsule.height, target_h, minf(1.0, 12.0 * delta))
	collider.position.y = capsule.height * 0.5

func _update_camera(delta: float, on_floor: bool, sprinting: bool) -> void:
	var eye := EYE_CROUCH if crouching else EYE_STAND
	var moving := Vector2(velocity.x, velocity.z).length()
	var bob_y := 0.0
	var bob_x := 0.0
	if on_floor and moving > 0.5:
		bob_time += delta * moving * (1.5 if sprinting else 1.9)
		var amount := 0.5 if aiming else 1.0
		bob_y = sin(bob_time * 2.0) * 0.032 * amount * (1.5 if sprinting else 1.0)
		bob_x = cos(bob_time) * 0.022 * amount
	head.position.y = lerpf(head.position.y, eye + bob_y, minf(1.0, 14.0 * delta))
	head.position.x = lerpf(head.position.x, bob_x, minf(1.0, 10.0 * delta))
	kick = lerpf(kick, 0.0, minf(1.0, 12.0 * delta))
	head.rotation.x = pitch + kick
	camera.rotation.z = lerpf(camera.rotation.z, -bob_x * 0.6, minf(1.0, 8.0 * delta))
	var target_fov := FOV_ADS if aiming else (FOV_HIP + (5.0 if sprinting else 0.0))
	camera.fov = lerpf(camera.fov, target_fov, minf(1.0, 10.0 * delta))

# --- silah ---------------------------------------------------------------

func _update_weapon(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	var w := WeaponData.get_weapon(weapon_index)
	var target_pos := _ads_pos if aiming else _hip_pos
	var dip := 0.0
	if reload_left > 0.0:
		reload_left = maxf(0.0, reload_left - delta)
		var t := 1.0 - reload_left / float(w["reload"])
		dip = sin(t * PI) * 0.32
		if reload_left <= 0.0:
			_finish_reload()
	viewmodel.position = viewmodel.position.lerp(target_pos + Vector3(0.0, -dip, dip * 0.4), minf(1.0, 14.0 * delta))
	viewmodel.rotation.x = lerpf(viewmodel.rotation.x, dip * 1.4 + kick * 2.0, minf(1.0, 12.0 * delta))
	muzzle_timer = maxf(0.0, muzzle_timer - delta)
	muzzle_light.light_energy = 6.0 if muzzle_timer > 0.0 else 0.0
	if reload_left > 0.0:
		return
	var auto := bool(w["auto"])
	var pressed := Input.is_action_pressed("fire") if auto else Input.is_action_just_pressed("fire")
	if Input.is_action_just_pressed("reload"):
		start_reload()
	elif pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		fire()

func fire() -> void:
	if fire_cooldown > 0.0:
		return
	if clips[weapon_index] <= 0:
		start_reload()
		return
	var w := WeaponData.get_weapon(weapon_index)
	clips[weapon_index] -= 1
	fire_cooldown = float(w["rate"])
	var spread := float(w["spread"]) * (0.35 if aiming else 1.0) * (1.6 if not is_on_floor() else 1.0)
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	dir = (dir + camera.global_transform.basis.x * randf_range(-spread, spread) + camera.global_transform.basis.y * randf_range(-spread, spread)).normalized()
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 250.0)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var col: Object = hit["collider"]
		if col != null and col.has_method("take_damage"):
			var killed: bool = col.take_damage(float(w["damage"]), hit["position"])
			hit_confirmed.emit(killed)
		_spawn_impact(hit["position"], hit["normal"])
	kick += 0.012 + 0.006 * float(w["damage"]) / 70.0
	viewmodel.position.z += 0.05
	muzzle_timer = 0.05
	_emit_ammo()
	if clips[weapon_index] <= 0 and reserves[weapon_index] > 0:
		start_reload()

func start_reload() -> void:
	var w := WeaponData.get_weapon(weapon_index)
	if reload_left > 0.0 or clips[weapon_index] >= int(w["clip"]) or reserves[weapon_index] <= 0:
		return
	reload_left = float(w["reload"])
	reload_started.emit(reload_left)

func _finish_reload() -> void:
	var w := WeaponData.get_weapon(weapon_index)
	var need := int(w["clip"]) - clips[weapon_index]
	var take := mini(need, reserves[weapon_index])
	clips[weapon_index] += take
	reserves[weapon_index] -= take
	_emit_ammo()

func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.04
	s.height = 0.08
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	m.material_override = mat
	get_tree().current_scene.add_child(m)
	m.global_position = pos + normal * 0.02
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ZERO, 0.4)
	tw.tween_callback(m.queue_free)

func _build_viewmodel() -> void:
	for c in viewmodel.get_children():
		if c != muzzle_light:
			c.queue_free()
	var w := WeaponData.get_weapon(weapon_index)
	var length := float(w["length"])
	if weapon_index == 0:
		var scene := load("res://assets/models/rifle_kar98k.glb") as PackedScene
		if scene != null:
			var rifle := scene.instantiate() as Node3D
			rifle.scale = Vector3.ONE * 0.62
			rifle.position = Vector3(0, -0.02, -0.28)
			viewmodel.add_child(rifle)
			return
	var metal: Color = w["color"]
	var barrel := _box(Vector3(0.035, 0.035, length), Vector3(0, 0.02, -length * 0.5), metal.darkened(0.3))
	var body := _box(Vector3(0.05, 0.08, length * 0.42), Vector3(0, 0.0, -length * 0.18), metal)
	var grip := _box(Vector3(0.035, 0.1, 0.045), Vector3(0, -0.07, -0.02), metal.lightened(0.12))
	grip.rotation.x = 0.3
	var stock := _box(Vector3(0.045, 0.075, length * 0.3), Vector3(0, -0.02, length * 0.12), Color(0.35, 0.24, 0.15))
	for m: MeshInstance3D in [barrel, body, grip, stock]:
		viewmodel.add_child(m)
	if weapon_index == 1:
		viewmodel.add_child(_box(Vector3(0.05, 0.22, 0.05), Vector3(0, -0.15, -length * 0.4), metal.darkened(0.2)))
	var skin := Color(0.85, 0.62, 0.5)
	var hand_a := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	hand_a.mesh = sphere
	hand_a.position = Vector3(0, -0.09, -0.02)
	hand_a.material_override = _mat(Color(0.3, 0.22, 0.17))
	viewmodel.add_child(hand_a)
	var hand_b := hand_a.duplicate() as MeshInstance3D
	hand_b.position = Vector3(0, -0.035, -length * 0.55)
	viewmodel.add_child(hand_b)

func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = _mat(color)
	return m

func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	return mat

# --- can / ölüm ------------------------------------------------------------

func take_damage(amount: float, _pos: Vector3 = Vector3.ZERO) -> bool:
	if dead or Time.get_ticks_msec() < invulnerable_until:
		return false
	hp = maxf(0.0, hp - amount)
	health_changed.emit(hp, MAX_HP)
	damaged.emit()
	if hp <= 0.0:
		dead = true
		died.emit()
		get_tree().create_timer(2.5).timeout.connect(respawn)
	return dead

func respawn() -> void:
	hp = MAX_HP
	stamina = MAX_STAMINA
	exhausted = false
	dead = false
	reload_left = 0.0
	# ölünce mermiler sıfırlanmaz: her silah tam dolu başlar
	for i in WeaponData.WEAPONS.size():
		clips[i] = int(WeaponData.WEAPONS[i]["clip"])
		reserves[i] = int(WeaponData.WEAPONS[i]["reserve"])
	global_position = spawn_position
	velocity = Vector3.ZERO
	invulnerable_until = Time.get_ticks_msec() + 3000.0
	_emit_all()
	respawned.emit()
