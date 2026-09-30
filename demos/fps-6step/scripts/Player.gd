class_name Player
extends CharacterBody3D

signal health_depleted

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const CROUCH_SPEED_FACTOR := 0.45
const EYE_HEIGHT := 1.55
const FIRE_RANGE := 80.0
const BOB_FREQ := 1.55
const BOB_AMOUNT := 0.045
const BOB_SIDE := 0.035

@export var move_speed: float = 6.0
@export var sprint_multiplier: float = 1.6
@export var acceleration: float = 12.0
@export var mouse_sensitivity: float = 0.0022
@export var jump_velocity: float = 7.0
@export var gravity: float = 22.0
@export var fire_rate: float = 0.28
@export var reload_duration: float = 1.4
@export var base_spread: float = 0.4
@export var sprint_spread: float = 2.4
@export var recoil_pitch: float = 0.022
@export var recoil_yaw: float = 0.008

var stats: PlayerStats
var _pitch: float = 0.0
var _bob_time: float = 0.0
var _jump_count: int = 0
var _fire_count: int = 0
var _sprint_amount: float = 0.0
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _fire_timer: float = 0.0
var _reloading: float = 0.0
var _bob_intensity: float = 0.0
var _kick: float = 0.0
var _kick_vel: float = 0.0
var _mouse_delta: Vector2 = Vector2.ZERO
var _ads: bool = false
var _sprint_blocked_in_air: bool = false
var _ads_amount: float = 0.0
var _crouch: bool = false
var _crouch_amount: float = 0.0
var _reload_t: float = 0.0
var _reload_total: float = 0.0
var _hud: HUD = null

@onready var _body: MeshInstance3D = $Body
@onready var _collider: CollisionShape3D = $CollisionShape3D
@onready var _cap_shape: CapsuleShape3D = _collider.shape
@onready var _head: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _muzzle: Node3D = $CameraPivot/Camera3D/Muzzle
@onready var _gun: Node3D = $CameraPivot/Camera3D/Gun
@onready var _flash_mesh: MeshInstance3D = $CameraPivot/Camera3D/FlashMesh
@onready var _flash: OmniLight3D = $CameraPivot/Camera3D/MuzzleFlash
@onready var _tracer: MeshInstance3D = $CameraPivot/Camera3D/Gun/Tracer
@onready var _tracer_mat: StandardMaterial3D = _tracer.get_active_material(0)
@onready var _impact: MeshInstance3D = $CameraPivot/Camera3D/Gun/Impact
@onready var _impact_mat: StandardMaterial3D = _impact.get_active_material(0)


func _ready() -> void:
	stats = PlayerStats.new()
	stats.health_changed.connect(_on_health_changed)
	stats.stamina_changed.connect(_on_stamina_changed)
	stats.ammo_changed.connect(_on_ammo_changed)
	stats.weapon_reloaded.connect(_on_reloaded)
	_flash.light_energy = 0.0
	_flash_mesh.visible = false
	_tracer.visible = false
	_impact.visible = false
	_apply_weapon(stats.weapon())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Silah değiştiğinde model ölçeğini ve renk tonunu yeni silaha uyarlar.
func _apply_weapon(w: WeaponData) -> void:
	_gun.scale = Vector3.ONE * w.gun_scale
	var body_mat := $CameraPivot/Camera3D/Gun/WeaponMesh.material_override as StandardMaterial3D
	if body_mat:
		body_mat.albedo_color = w.tint
	var barrel := $CameraPivot/Camera3D/Gun/Barrel
	barrel.scale = Vector3(1.0, w.barrel_length / 0.38, 1.0)
	barrel.position.z = -0.12 - w.barrel_length * 0.5
	if _hud:
		_hud.set_weapon(w.display_name)


func register_hud(hud: HUD) -> void:
	_hud = hud
	hud.on_health(stats.health, PlayerStats.MAX_HEALTH)
	hud.on_stamina(stats.stamina, PlayerStats.MAX_STAMINA)
	hud.on_ammo(stats.clip(), stats.reserve())
	hud.set_hint("WASD yürü  •  Shift koş  •  Boşluk zıpla  •  Sol tık ateş  •  R doldur  •  Esc imleci bırak")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_mouse_delta += mm.relative
		rotate_y(-mm.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - mm.relative.y * mouse_sensitivity, deg_to_rad(-89.0), deg_to_rad(89.0))
		_head.rotation.x = _pitch
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event.is_action_pressed("reload"):
		_start_reload()
	elif event.is_action_pressed("ads"):
		_set_ads(true)
	elif event.is_action_pressed("ads_release"):
		_set_ads(false)
	elif event.is_action_pressed("crouch"):
		_crouch = not _crouch
	elif event.is_action_pressed("weapon_next"):
		_switch_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		_switch_weapon(-1)
	else:
		for i in 3:
			if event.is_action_pressed("weapon_%d" % (i + 1)):
				_switch_to(i)


func _set_ads(on: bool) -> void:
	_ads = on


## Eğilme: kapsül ve kamera alçalır, hareket yavaşlar, hassasiyet biraz düşer.
func _update_crouch(delta: float) -> void:
	var want := _crouch
	if want and not _can_stand_up():
		want = false
		_crouch = false
	_crouch_amount = move_toward(_crouch_amount, 1.0 if want else 0.0, delta * 8.0)
	var h := lerpf(STAND_HEIGHT, CROUCH_HEIGHT, _crouch_amount)
	_cap_shape.height = h
	_collider.position.y = h * 0.5
	_body.scale.y = lerpf(1.0, CROUCH_HEIGHT / STAND_HEIGHT, _crouch_amount)
	_body.position.y = h * 0.5
	if _hud:
		_hud.set_crouch(_crouch_amount > 0.5)


## Baş üstünde engel varsa kalkmaya izin verme.
func _can_stand_up() -> bool:
	if _crouch_amount < 0.01:
		return true
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, CROUCH_HEIGHT, 0.0)
	var to := global_position + Vector3(0.0, STAND_HEIGHT + 0.1, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


func _switch_weapon(delta: int) -> void:
	_reloading = 0.0
	if stats.cycle(delta):
		_apply_weapon(stats.weapon())
		if _hud:
			_hud.set_hint("Silah: %s  —  1/2/3 veya tekerlek ile değiştir" % stats.weapon().display_name)


func _switch_to(index: int) -> void:
	_reloading = 0.0
	if stats.select(index):
		_apply_weapon(stats.weapon())
		if _hud:
			_hud.set_hint("Silah: %s" % stats.weapon().display_name)


## Düşmanların ateşinden gelen hasar.
func damage_player(amount: float) -> void:
	stats.damage(amount)


func _physics_process(delta: float) -> void:
	_fire_timer = maxf(0.0, _fire_timer - delta)
	if _reloading > 0.0:
		_reloading -= delta
		_reload_t += delta
		if _reloading <= 0.0:
			_reloading = 0.0
			_reload_t = 0.0
			stats.reload()
	_update_crouch(delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var raw_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var on_floor := is_on_floor()
	var want_sprint: bool = Input.is_action_pressed("sprint") and raw_dir.length() > 0.1 and on_floor and not _crouch and stats.can_sprint(true)
	# Havada iken Shift barı hiç düşürmez; stamina yalnızca yerde koşarken harcanır.
	if want_sprint:
		stats.spend_stamina(delta)
	else:
		stats.regen_stamina(delta)
	_sprint_amount = move_toward(_sprint_amount, 1.0 if want_sprint else 0.0, delta * (5.0 if on_floor else 9.0))

	var speed := move_speed * lerpf(1.0, sprint_multiplier, _sprint_amount) * lerpf(1.0, CROUCH_SPEED_FACTOR, _crouch_amount)
	var target := raw_dir * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * speed * delta)

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
			_jump_count += 1
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	var planar := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and planar > 0.6:
		_bob_time += delta * planar * BOB_FREQ
		_bob_intensity = move_toward(_bob_intensity, 1.0, delta * 6.0)
	else:
		_bob_intensity = move_toward(_bob_intensity, 0.0, delta * 6.0)

	_apply_camera(delta)
	_update_gun(delta, raw_dir)

	if _hud:
		_hud.sway(_mouse_delta * 0.35)
		_hud.set_bob(_bob_time, BOB_AMOUNT * 3.0 * _bob_intensity)
		_hud.set_yaw(rotation.y)
		if _hud:
			_hud.set_reload_progress(0.0 if _reload_total <= 0.0 else 1.0 - _reloading / _reload_total)
	_mouse_delta = Vector2.ZERO

	var w := stats.weapon()
	var want_fire: bool = Input.is_action_pressed("fire") if w.auto else Input.is_action_just_pressed("fire")
	if want_fire and _fire_timer <= 0.0 and _reloading <= 0.0:
		_try_fire()


func _apply_camera(delta: float) -> void:
	_recoil_pitch = move_toward(_recoil_pitch, 0.0, delta * 0.9)
	_recoil_yaw = move_toward(_recoil_yaw, 0.0, delta * 0.9)
	_head.rotation.x = _pitch + _recoil_pitch
	_head.rotation.z = sin(_bob_time) * 0.008 * _bob_intensity

	var s := sin(_bob_time)
	_ads_amount = move_toward(_ads_amount, 1.0 if _ads else 0.0, delta * 7.0)
	var base_fov := _camera.fov
	var w := stats.weapon()
	var ads_fov := lerpf(70.0, 26.0, w.ads_zoom)
	_camera.fov = lerpf(base_fov, ads_fov, _ads_amount)
	# ADS'te silah gövdeye yaklaşır, kamera hafifçe geri çekilir.
	# Eğilme: göz seviyesi alçalır; reload sırasında kamera hafifçe aşağı iner.
	var eye := lerpf(EYE_HEIGHT, 0.98, _crouch_amount) - _crouch_amount * 0.05
	var reload_dip := sin(clampf(_reload_t / maxf(_reload_total, 0.001), 0.0, 1.0) * PI) * 0.10
	_camera.position.y = eye + s * BOB_AMOUNT * _bob_intensity - reload_dip
	_camera.position.x = cos(_bob_time * 0.5) * BOB_SIDE * _bob_intensity
	_camera.position.z = _kick * 0.06 + _ads_amount * 0.12
	_gun.position = _gun.position.lerp(
		Vector3(0.22, -0.17, -0.62).lerp(Vector3(0.02, -0.13, -0.46), _ads_amount),
		clampf(delta * 16.0, 0.0, 1.0))


func _update_gun(delta: float, move_dir: Vector3) -> void:
	# Yaylı geri tepme: namlu geriye fırlar, sonra yerine oturur.
	_kick_vel += -_kick * 190.0 * delta
	_kick_vel *= 1.0 - clampf(11.0 * delta, 0.0, 1.0)
	_kick += _kick_vel * delta
	# Reload: silah aşağı sallanır, eğilir ve gövdeye yaklaşır.
	var e := 0.0
	if _reloading > 0.0 and _reload_total > 0.0:
		e = sin(_reload_t / _reload_total * PI * 4.0) * 1.0
	var reload_off := Vector3(-0.06, -0.20, -0.08) * (1.0 if _reloading > 0.0 else 0.0)
	var reload_rot := Vector3(-0.30, 0.50, 0.22) * (1.0 if _reloading > 0.0 else 0.0)
	var sway := Vector2(sin(_bob_time) * 0.012, cos(_bob_time * 2.0) * 0.008) * _bob_intensity
	var rest := Vector3(0.22, -0.17, -0.62).lerp(Vector3(0.02, -0.12, -0.34), _ads_amount)
	var target := rest + Vector3(sway.x, -sway.y + _recoil_pitch * 1.2 + _kick * 0.05, _recoil_pitch * 2.0 + _kick * 0.10) + reload_off
	target.y += e * 0.05
	_gun.position = _gun.position.lerp(target, clampf(delta * 16.0, 0.0, 1.0))
	var target_rot := Vector3(_recoil_pitch * 2.0 + _kick * 0.55, 0.0, -move_dir.x * 0.05 + _kick * 0.12) + reload_rot
	_gun.rotation = _gun.rotation.lerp(target_rot, clampf(delta * 10.0, 0.0, 1.0))

	_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 22.0)
	_flash_mesh.visible = _flash.light_energy > 0.15
	if _tracer.visible:
		_tracer_mat.albedo_color.a = maxf(0.0, _tracer_mat.albedo_color.a - delta * 14.0)
		if _tracer_mat.albedo_color.a <= 0.0:
			_tracer.visible = false
	if _impact.visible:
		_impact_mat.albedo_color.a = maxf(0.0, _impact_mat.albedo_color.a - delta * 5.0)
		if _impact_mat.albedo_color.a <= 0.0:
			_impact.visible = false


func _try_fire() -> void:
	var w := stats.weapon()
	if not stats.has_ammo():
		_start_reload()
		return
	_fire_timer = w.fire_rate
	_fire_count += 1
	stats.consume_round()
	_recoil_pitch = minf(_recoil_pitch + w.recoil_pitch, 0.09)
	_recoil_yaw += randf_range(-w.recoil_yaw, w.recoil_yaw)
	_kick_vel += w.kick
	_flash.light_energy = 3.2
	_shoot_ray()


func _shoot_ray() -> void:
	var space := get_world_3d().direct_space_state
	var from := _camera.global_position
	var w := stats.weapon()
	var spread := deg_to_rad(lerpf(
		lerpf(w.base_spread, w.ads_spread, _ads_amount),
		w.sprint_spread, _sprint_amount))
	var dir := -_camera.global_transform.basis.z
	dir = dir.rotated(Vector3.RIGHT, randf_range(-spread, spread))
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	dir = dir.normalized()
	var to := from + dir * FIRE_RANGE

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	var end: Vector3 = hit.get("position", to)

	var muzzle_pos := _muzzle.global_position
	var length := muzzle_pos.distance_to(end)
	var mid := (muzzle_pos + end) * 0.5
	_tracer.global_position = mid
	if length > 0.01:
		_tracer.look_at(end, Vector3.UP)
		_tracer.scale = Vector3(1.0, 1.0, length)
	_tracer.visible = true
	_tracer_mat.albedo_color.a = 0.9

	_impact.global_position = end + dir * 0.03
	_impact.visible = true
	_impact_mat.albedo_color.a = 0.8

	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider and collider.has_method("take_hit"):
			var local_hit := (end as Vector3) - (collider as Node3D).global_position
			var is_head := local_hit.y > Target.HEAD_HEIGHT
			collider.take_hit(_camera.global_position, is_head)
			if _hud:
				_hud.on_hit()


func _start_reload() -> void:
	if _reloading > 0.0 or stats.clip() >= stats.clip_size() or stats.reserve() <= 0:
		return
	_reloading = stats.weapon().reload_time
	_reload_total = _reloading
	_reload_t = 0.0


## Yeniden doğuş: mermiler dolu, şarjördeki kayıp geri gelir.
func respawn() -> void:
	_reloading = 0.0
	_reload_t = 0.0
	stats.respawn()
	if _hud:
		_hud.set_hint("Yeniden doğdun — şarjörlerin ve yedek mermilerin doldu.")


func _on_reloaded() -> void:
	if _hud:
		_hud.on_ammo(stats.clip(), stats.reserve())


func _on_stamina_changed(current: float, maximum: float) -> void:
	if _hud:
		_hud.on_stamina(current, maximum)


func _on_ammo_changed(clip: int, reserve: int) -> void:
	if _hud:
		_hud.on_ammo(clip, reserve)


func _on_health_changed(current: float, maximum: float) -> void:
	if _hud:
		_hud.on_health(current, maximum)
	if current <= 0.0:
		health_depleted.emit()
