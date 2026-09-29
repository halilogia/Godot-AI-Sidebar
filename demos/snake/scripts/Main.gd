extends Node2D

const CELL := 32
const COLS := 24
const ROWS := 18
const MOVE_TIME := 0.11
const START_TIME := 0.22

enum State { READY, PLAYING, DEAD }

var body: Array[Vector2i] = []
var dir := Vector2i(1, 0)
var next_dir := Vector2i(1, 0)
var food := Vector2i.ZERO
var state: int = State.READY
var score := 0
var high := 0
var tick := 0.0
var flash := 0.0
var shake := 0.0
var board_origin := Vector2.ZERO

var score_label: Label
var best_label: Label
var hint_label: Label
var overlay: Control
var overlay_title: Label
var overlay_body: Label

func _ready() -> void:
	score_label = get_node("HUD/Bar/Row/ScoreBox/ScoreValue")
	best_label = get_node("HUD/Bar/Row/BestBox/BestValue")
	hint_label = get_node("HUD/Hint")
	overlay = get_node("HUD/Overlay")
	overlay_title = overlay.get_node("Box/Margin/Text/Title")
	overlay_body = overlay.get_node("Box/Margin/Text/Body")
	randomize()
	var hud_h := 84.0
	board_origin = Vector2(
		(1280.0 - float(COLS * CELL)) * 0.5,
		hud_h + (720.0 - hud_h - float(ROWS * CELL)) * 0.5)
	_reset()

func _reset() -> void:
	body.clear()
	var start := Vector2i(4, ROWS / 2)
	for i in 4:
		body.append(start - Vector2i(i, 0))
	dir = Vector2i(1, 0)
	next_dir = dir
	score = 0
	tick = 0.0
	flash = 0.0
	shake = 0.0
	_spawn_food()
	_update_hud()
	queue_redraw()

func _spawn_food() -> void:
	var free: Array[Vector2i] = []
	for x in COLS:
		for y in ROWS:
			if not body.has(Vector2i(x, y)):
				free.append(Vector2i(x, y))
	if free.is_empty():
		food = Vector2i(-1, -1)
		return
	food = free[randi() % free.size()]

func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	shake = maxf(0.0, shake - delta * 30.0)
	if state == State.DEAD:
		queue_redraw()
		return
	tick += delta
	var interval := maxf(0.045, START_TIME - float(score) * 0.004)
	if tick < interval:
		return
	tick = 0.0
	_step()
	queue_redraw()

func _step() -> void:
	if body.is_empty():
		return
	dir = next_dir
	var head: Vector2i = body[0] + dir
	if head.x < 0 or head.y < 0 or head.x >= COLS or head.y >= ROWS or body.has(head):
		_die()
		return
	body.insert(0, head)
	if head == food:
		score += 1
		flash = 0.12
		_spawn_food()
		_update_hud()
	else:
		body.remove_at(body.size() - 1)

func _die() -> void:
	state = State.DEAD
	shake = 6.0
	if score > high:
		high = score
		_update_hud()
	overlay_title.text = "OYUN BİTTİ"
	overlay_body.text = "Skor: %d\nEn iyi: %d\n\nR ile yeniden başla" % [score, high]
	overlay.visible = true
	get_node("HUD/Hint").visible = false

func _update_hud() -> void:
	score_label.text = str(score)
	best_label.text = str(high)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.keycode:
			KEY_W, KEY_UP:
				_try_dir(Vector2i(0, -1))
			KEY_S, KEY_DOWN:
				_try_dir(Vector2i(0, 1))
			KEY_A, KEY_LEFT:
				_try_dir(Vector2i(-1, 0))
			KEY_D, KEY_RIGHT:
				_try_dir(Vector2i(1, 0))
			KEY_R, KEY_SPACE, KEY_ENTER:
				_restart()
			KEY_ESCAPE:
				get_tree().quit()

func _try_dir(d: Vector2i) -> void:
	if d + dir != Vector2i.ZERO:
		next_dir = d
	if state == State.READY:
		state = State.PLAYING
		get_node("HUD/Hint").visible = false

func _restart() -> void:
	overlay.visible = false
	get_node("HUD/Hint").visible = true
	state = State.READY
	_reset()

func _cell_rect(c: Vector2i) -> Rect2:
	var o := board_origin + Vector2(float(c.x) * CELL, float(c.y) * CELL)
	if shake > 0.0:
		o += Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	return Rect2(o + Vector2(2, 2), Vector2(CELL - 4, CELL - 4))

func _draw() -> void:
	# background
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("#0B1020"))
	for i in 12:
		var a := 0.02 + 0.004 * float(i)
		draw_rect(Rect2(0, 60.0 * i, 1280, 30), Color("#141C33", a), true)

	# board panel
	var board := Rect2(board_origin, Vector2(COLS * CELL, ROWS * CELL))
	draw_rect(board.grow(8), Color("#141C33"), true)
	draw_rect(board.grow(8), Color("#1E2A47"), false, 2.0)

	# grid
	for x in COLS + 1:
		draw_line(board_origin + Vector2(x * CELL, 0), board_origin + Vector2(x * CELL, ROWS * CELL), Color("#2A3A63", 0.9), 1.0)
	for y in ROWS + 1:
		draw_line(board_origin + Vector2(0, y * CELL), board_origin + Vector2(COLS * CELL, y * CELL), Color("#2A3A63", 0.9), 1.0)

	# food
	if food.x >= 0:
		var f := _cell_rect(food)
		draw_circle(f.get_center(), CELL * 0.28, Color("#FFD166", 0.25))
		draw_circle(f.get_center(), CELL * 0.17, Color("#FFD166"))

	# snake
	for i in range(body.size() - 1, -1, -1):
		var r := _cell_rect(body[i])
		var t := 1.0 - float(i) / maxf(1.0, float(body.size()))
		var col := Color("#7CFF6B").lerp(Color("#2E7A46"), 1.0 - t)
		if i == 0:
			col = Color("#7CFF6B")
		draw_rect(r, col, true)
		if i == 0:
			draw_circle(r.get_center(), CELL * 0.2, Color("#7CFF6B", 0.35))
			var e := r.grow(-8)
			var perp := Vector2(-dir.y, dir.x) * 6.0
			draw_circle(r.get_center() + dir * 7.0 + perp, 2.5, Color("#0B1020"))
			draw_circle(r.get_center() + dir * 7.0 - perp, 2.5, Color("#0B1020"))

	# eat flash
	if flash > 0.0:
		draw_rect(board, Color("#7CFF6B", flash * 1.4), false, 4.0)
