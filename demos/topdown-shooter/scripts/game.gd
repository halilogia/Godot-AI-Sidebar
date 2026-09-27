extends Node2D

## Oyun dongusu: dalga yonetimi, spawn, skor ve oyun sonu ekrani.

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const ARENA_SIZE := Vector2(2400.0, 1600.0)
const ENEMIES_PER_WAVE := 4
const ENEMIES_PER_WAVE_STEP := 2
const MAX_ALIVE := 60
const SPAWN_INTERVAL := 0.5
const WAVE_BREAK_TIME := 3.0
const MIN_SPAWN_DISTANCE := 600.0
const WAVE_HEAL := 20

enum State { WAVE_BREAK, COMBAT, GAME_OVER }

var _state: State = State.WAVE_BREAK
var _break_timer: float = 1.5
var _spawn_timer: float = 0.0
var _wave: int = 0
var _to_spawn: int = 0
var _spawned: int = 0
var _alive: int = 0
var _score: int = 0

@onready var _enemies_root: Node2D = $Entities/Enemies
@onready var _player: Player = $Entities/Player
@onready var _health_bar: ProgressBar = $HUD/HealthBar
@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _wave_label: Label = $HUD/WaveLabel
@onready var _status_label: Label = $HUD/StatusLabel
@onready var _game_over: Control = $HUD/GameOver
@onready var _final_score_label: Label = $HUD/GameOver/Center/Panel/FinalScore


func _ready() -> void:
	_player.health_changed.connect(_on_player_health_changed)
	_player.died.connect(_on_player_died)
	_health_bar.max_value = _player.max_health
	_score_label.text = "SKOR 0"
	_wave_label.text = "DALGA 0"
	_status_label.text = "Hazir"
	_game_over.hide()


func _process(delta: float) -> void:
	match _state:
		State.WAVE_BREAK:
			_process_wave_break(delta)
		State.COMBAT:
			_process_combat(delta)


func _unhandled_input(_event: InputEvent) -> void:
	if _state == State.GAME_OVER and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()


func _process_wave_break(delta: float) -> void:
	_break_timer = maxf(_break_timer - delta, 0.0)
	_status_label.text = "Sonraki dalga: %.1f" % _break_timer
	if _break_timer <= 0.0:
		_start_wave()


func _process_combat(delta: float) -> void:
	_status_label.text = "Kalan: %d" % (_to_spawn - _spawned + _alive)
	_spawn_timer = maxf(_spawn_timer - delta, 0.0)
	if _spawned < _to_spawn and _spawn_timer <= 0.0 and _alive < MAX_ALIVE:
		_spawn_enemy()
		_spawn_timer = SPAWN_INTERVAL


func _start_wave() -> void:
	_wave += 1
	_to_spawn = ENEMIES_PER_WAVE + (_wave - 1) * ENEMIES_PER_WAVE_STEP
	_spawned = 0
	_spawn_timer = 0.0
	_state = State.COMBAT
	_wave_label.text = "DALGA %d" % _wave


func _spawn_enemy() -> void:
	var enemy := ENEMY_SCENE.instantiate()
	var difficulty := float(_wave - 1)
	enemy.set("speed", 105.0 + difficulty * 7.0)
	enemy.set("max_health", 3 + int(difficulty / 2.0))
	enemy.set("points", 10 + _wave * 2)
	enemy.global_position = _pick_spawn_position()

	_enemies_root.add_child(enemy)
	enemy.connect("died", _on_enemy_died)
	_spawned += 1
	_alive += 1


func _pick_spawn_position() -> Vector2:
	var margin := 60.0
	var position := Vector2(ARENA_SIZE * 0.5)
	for _attempt in 12:
		match randi() % 4:
			0:
				position = Vector2(randf_range(0.0, ARENA_SIZE.x), margin)
			1:
				position = Vector2(randf_range(0.0, ARENA_SIZE.x), ARENA_SIZE.y - margin)
			2:
				position = Vector2(margin, randf_range(0.0, ARENA_SIZE.y))
			_:
				position = Vector2(ARENA_SIZE.x - margin, randf_range(0.0, ARENA_SIZE.y))
		if position.distance_to(_player.global_position) >= MIN_SPAWN_DISTANCE:
			return position
	return position


func _on_enemy_died(enemy: Node2D, points: int) -> void:
	_alive = maxi(_alive - 1, 0)
	_score += points
	_score_label.text = "SKOR %d" % _score
	if enemy.is_connected("died", _on_enemy_died):
		enemy.disconnect("died", _on_enemy_died)

	if _state != State.COMBAT or _spawned < _to_spawn or _alive > 0:
		return
	_state = State.WAVE_BREAK
	_break_timer = WAVE_BREAK_TIME
	_player.heal(WAVE_HEAL)
	_status_label.text = "Dalga %d temizlendi" % _wave


func _on_player_health_changed(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current


func _on_player_died() -> void:
	_state = State.GAME_OVER
	_status_label.text = ""
	_final_score_label.text = "Skor: %d   Dalga: %d" % [_score, _wave]
	_game_over.show()
