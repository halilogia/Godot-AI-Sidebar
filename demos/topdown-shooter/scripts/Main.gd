extends Node2D

const ENEMY_SCRIPT := preload("res://scripts/Enemy.gd")
const PICKUP_SCRIPT := preload("res://scripts/Pickup.gd")
const ARENA := Rect2(0, 0, 880, 560)

@onready var world: Node2D = $World
@onready var player: Player = $World/Player
@onready var cam: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD
@onready var banner: Label = $HUD/Banner
@onready var damage: ColorRect = $HUD/Damage

var wave_delay := 1.2
var pending := 0
var spawn_timer := 0.0
var game_over := false

func _ready() -> void:
	Global.reset()
	player.arena_rect = ARENA
	Global.player_died.connect(_on_player_died)
	_spawn_wave(1)

func _process(delta: float) -> void:
	_update_shake(delta)
	if Global.damage_flash > 0.0:
		Global.damage_flash = maxf(0.0, Global.damage_flash - delta)
		damage.modulate.a = Global.damage_flash / 0.1 * 0.35
	else:
		damage.modulate.a = 0.0
	if game_over:
		return
	if pending > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_enemy()
			pending -= 1
			spawn_timer = 0.45
	elif get_tree().get_nodes_in_group("enemy").is_empty():
		wave_delay -= delta
		if wave_delay <= 0.0:
			_spawn_wave(Global.wave + 2)
			wave_delay = 2.5

func _update_shake(delta: float) -> void:
	if Global.shake > 0.05:
		Global.shake = maxf(0.0, Global.shake - delta * 22.0)
		cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Global.shake
	else:
		cam.offset = cam.offset.lerp(Vector2.ZERO, 0.3)

func _spawn_wave(n: int) -> void:
	Global.wave = n
	Global.wave_changed.emit(n)
	_show_banner("WAVE %d" % n)
	pending = 3 + n * 2
	spawn_timer = 0.2
	if n % 2 == 0:
		_spawn_pickup("heal")
	elif n % 3 == 0:
		_spawn_pickup("score")

func _spawn_enemy() -> void:
	var e: CharacterBody2D = ENEMY_SCRIPT.new()
	e.position = Vector2(
		randf_range(ARENA.position.x + 40.0, ARENA.end.x - 40.0),
		randf_range(ARENA.position.y + 40.0, ARENA.end.y - 40.0))
	e.target = player
	e.bounds = ARENA
	e.speed = 95.0 + Global.wave * 8.0
	e.hp = 2 if Global.wave < 3 else 3
	e.points = 10 * Global.wave
	world.add_child(e)

func _spawn_pickup(kind: String) -> void:
	var p: Node2D = PICKUP_SCRIPT.new()
	p.kind = kind
	p.position = Vector2(
		randf_range(ARENA.position.x + 50.0, ARENA.end.x - 50.0),
		randf_range(ARENA.position.y + 50.0, ARENA.end.y - 50.0))
	world.add_child(p)

func _show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if game_over and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _on_player_died() -> void:
	game_over = true
	get_tree().call_group("fx", "burst", player.global_position, Palette.PRIMARY, 26)
	_show_banner("GAME OVER  -  press R to restart")
