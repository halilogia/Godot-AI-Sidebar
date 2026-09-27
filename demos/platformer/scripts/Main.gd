extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")

@onready var _level: Level = $Level
@onready var _holder: Node2D = $PlayerHolder
@onready var _hud: HUD = $HUD

var player: Player = null
var deaths: int = 0
var elapsed: float = 0.0
var won: bool = false


func _ready() -> void:
	_level.goal_reached.connect(_on_goal_reached)
	_spawn_player()


func _process(delta: float) -> void:
	if not won:
		elapsed += delta
		_hud.set_time(elapsed)
	_check_pit()
	if Input.is_action_just_pressed(&"restart"):
		get_tree().reload_current_scene()


func _check_pit() -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.global_position.y > _level.bounds.end.y:
		player.health = 0
		player.died.emit()


func _spawn_player() -> void:
	var p := PLAYER_SCENE.instantiate() as Player
	p.position = _level.spawn_position
	_holder.add_child(p)
	p.died.connect(_on_player_died)
	p.health_changed.connect(_hud.set_health)
	p.score_changed.connect(_hud.set_score)
	player = p
	_apply_camera_limits(p)
	_hud.set_health(p.health)
	_hud.set_score(0)
	_hud.set_deaths(deaths)


func _apply_camera_limits(p: Player) -> void:
	var cam: ShakeCamera = p.get_node(NodePath("Camera"))
	cam.limit_left = int(_level.bounds.position.x)
	cam.limit_right = int(_level.bounds.end.x)
	cam.limit_top = int(_level.bounds.position.y + 260.0)
	cam.limit_bottom = int(_level.bounds.end.y - 120.0)
	cam.reset_smoothing()


func _on_player_died() -> void:
	deaths += 1
	_hud.set_deaths(deaths)
	_hud.show_banner("OLDUN! Tekrar deneniyor...", 0.7)
	var old: Player = player
	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(old):
		old.queue_free()
	_spawn_player()


func _on_goal_reached() -> void:
	if won:
		return
	won = true
	if player:
		player.control_enabled = false
	_hud.show_banner("KAZANDIN!  SURE: %.1f s" % elapsed, 0.0)
