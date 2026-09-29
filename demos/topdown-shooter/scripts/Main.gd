extends Node2D

const ARENA := Vector2(1280, 720)
const SPAWN_MARGIN := 48.0

var player: Player
var bullets: Array[Bullet] = []
var enemies: Array[Enemy] = []
var score := 0
var wave := 1
var health := 5
var fire_timer := 0.0
var spawn_queue: Array[Vector2] = []
var spawn_timer := 0.0
var wave_break := 1.0
var shake := 0.0
var game_over := false
var wave_active := false

@onready var score_label: Label = $HUD/ScoreLabel
@onready var wave_label: Label = $HUD/WaveLabel
@onready var health_label: Label = $HUD/HealthLabel
@onready var banner: Label = $HUD/Banner

func _ready() -> void:
	randomize()
	player = Player.new()
	player.position = ARENA / 2.0
	add_child(player)
	move_child(player, get_child_count() - 1)
	banner.text = "DALGA 1"
	banner.modulate.a = 1.0
	_update_hud()

func _process(delta: float) -> void:
	if game_over:
		return
	_update_aim_and_fire(delta)
	_cleanup()
	_update_spawns(delta)
	_update_bullets()
	_update_enemy_contact()
	queue_redraw()
	if shake > 0.0:
		shake = max(0.0, shake - delta * 18.0)
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	else:
		position = Vector2.ZERO
	if banner.modulate.a > 0.0:
		banner.modulate.a = max(0.0, banner.modulate.a - delta * 0.5)

func _cleanup() -> void:
	var i := enemies.size() - 1
	while i >= 0:
		if not is_instance_valid(enemies[i]):
			enemies.remove_at(i)
		i -= 1

func _update_aim_and_fire(delta: float) -> void:
	var mouse := get_global_mouse_position()
	player.aim_at(mouse)
	fire_timer = max(0.0, fire_timer - delta)
	var wants := Input.is_action_pressed("shoot") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if wants and fire_timer <= 0.0:
		_spawn_bullet()
		fire_timer = Player.FIRE_RATE

func _spawn_bullet() -> void:
	var b := Bullet.new()
	b.position = player.position + player.aim * 22.0
	b.direction = player.aim
	add_child(b)
	bullets.append(b)

func _update_spawns(delta: float) -> void:
	if not wave_active:
		wave_break -= delta
		if wave_break <= 0.0:
			_start_wave()
		return
	if not spawn_queue.is_empty():
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = 0.45
			_spawn_enemy(spawn_queue.pop_back())
		return
	if enemies.is_empty():
		wave_active = false
		wave_break = 2.0
		wave += 1
		health = min(5, health + 1)
		_update_hud()
		banner.text = "DALGA %d" % wave
		banner.modulate.a = 1.0

func _start_wave() -> void:
	wave_active = true
	var count := 4 + wave * 2
	for i in count:
		spawn_queue.append(_random_edge_point())

func _random_edge_point() -> Vector2:
	var side := randi() % 4
	match side:
		0: return Vector2(randf_range(40, 1240), SPAWN_MARGIN)
		1: return Vector2(randf_range(40, 1240), ARENA.y - SPAWN_MARGIN)
		2: return Vector2(SPAWN_MARGIN, randf_range(40, 680))
		_: return Vector2(ARENA.x - SPAWN_MARGIN, randf_range(40, 680))

func _spawn_enemy(at: Vector2) -> void:
	var e := Enemy.new()
	e.position = at
	e.target = player
	e.speed = 90.0 + wave * 8.0
	e.hp = 3 + wave / 2
	add_child(e)
	enemies.append(e)

func _update_bullets() -> void:
	var i := bullets.size() - 1
	while i >= 0:
		var b := bullets[i]
		if not is_instance_valid(b):
			bullets.remove_at(i)
			i -= 1
			continue
		var hit := false
		for e in enemies:
			if not is_instance_valid(e):
				continue
			if b.global_position.distance_to(e.global_position) < 20.0:
				e.take_damage(1, b.global_position)
				score += 10
				shake = 3.0
				_update_hud()
				hit = true
				break
		if hit or not is_instance_valid(b):
			if is_instance_valid(b):
				b.queue_free()
			bullets.remove_at(i)
		i -= 1

func _update_enemy_contact() -> void:
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(player.global_position) < 30.0:
			e.take_damage(3, e.global_position)
			health -= 1
			shake = 6.0
			_update_hud()
			if health <= 0:
				_game_over()
				return

func _update_hud() -> void:
	score_label.text = "SKOR  %d" % score
	wave_label.text = "DALGA  %d" % wave
	health_label.text = "CAN  " + "◆".repeat(max(0, health))

func _game_over() -> void:
	game_over = true
	health = 0
	_update_hud()
	banner.text = "OYUN BİTTİ  —  R ile yeniden başla"
	banner.modulate.a = 1.0

func _unhandled_input(event: InputEvent) -> void:
	if game_over and event.is_action_pressed("shoot") == false and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _draw() -> void:
	var mouse := get_global_mouse_position()
	draw_arc(mouse, 12.0, 0, TAU, 24, Palette.ACCENT, 2.0)
	draw_arc(mouse, 3.0, 0, TAU, 12, Palette.ACCENT, 2.0)
