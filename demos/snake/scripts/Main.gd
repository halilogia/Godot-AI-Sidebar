class_name Main
extends Node2D
## Wires simulation, view, effects, HUD, input and juice together.

const SHAKE_TIME := 0.15
const SHAKE_MAX := 6.0

@onready var board: BoardView = $Board
@onready var effects: Effects = $Effects
@onready var hud: Hud = $Hud
@onready var flash: ColorRect = $Flash

var game := SnakeGame.new()
var best: int = 0
var _shake: float = 0.0
var _origin := Vector2.ZERO

func _ready() -> void:
	randomize()
	flash.color = Color(Palette.DANGER, 0.0)
	game.state_changed.connect(_on_state)
	game.food_eaten.connect(_on_food)
	game.died.connect(_on_died)
	_place()
	game.reset()
	hud.set_best(best)

func _place() -> void:
	# Board 768x512 centred horizontally, top at y=140 (below the 128px HUD).
	var w := float(SnakeGame.COLS * BoardView.CELL)
	var h := float(SnakeGame.ROWS * BoardView.CELL)
	var ox := (1280.0 - w) * 0.5
	var oy := 140.0
	_origin = Vector2(ox, oy)
	board.position = _origin
	effects.position = _origin
	board.game = game

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k in [KEY_W, KEY_UP]:
			game.turn(Vector2i.UP)
		elif k in [KEY_S, KEY_DOWN]:
			game.turn(Vector2i.DOWN)
		elif k in [KEY_A, KEY_LEFT]:
			game.turn(Vector2i.LEFT)
		elif k in [KEY_D, KEY_RIGHT]:
			game.turn(Vector2i.RIGHT)
		elif k == KEY_R:
			_restart()
		elif k == KEY_ESCAPE:
			get_tree().quit()

func _process(delta: float) -> void:
	game.tick(delta)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		var amp := SHAKE_MAX * (_shake / SHAKE_TIME)
		var off := Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		board.position = _origin + off
		effects.position = _origin + off
	else:
		board.position = _origin
		effects.position = _origin
	if flash.color.a > 0.0:
		flash.color.a = maxf(0.0, flash.color.a - delta * 6.0)

func _on_state(score: int, alive: bool) -> void:
	hud.set_score(score)

func _on_food(cell: Vector2i, points: int) -> void:
	var pos := Vector2(cell.x * BoardView.CELL + BoardView.CELL * 0.5,
			cell.y * BoardView.CELL + BoardView.CELL * 0.5)
	effects.spawn_ring(pos, Palette.ACCENT)
	effects.spawn_text(pos, "+%d" % points, Palette.ACCENT)
	_shake = SHAKE_TIME

func _on_died(cause: String) -> void:
	best = maxi(best, game.score)
	hud.set_best(best)
	flash.color = Color(Palette.DANGER, 0.35)
	_shake = SHAKE_TIME
	hud.show_banner("GAME OVER  —  press R", Palette.DANGER)

func _restart() -> void:
	game.reset()
	flash.color = Color(Palette.DANGER, 0.0)
	_shake = 0.0
	hud.show_banner("", Palette.DANGER)
