extends Node2D

const GRID_W := 20
const GRID_H := 20
const HUD_H := 96.0
const BASE_STEP := 0.14
const MIN_STEP := 0.05
const SAVE_PATH := "user://snake_best.txt"

var body: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var queued_direction := Vector2i.RIGHT
var food := Vector2i.ZERO
var score := 0
var best := 0
var state := "ready"
var step_time := BASE_STEP
var accumulator := 0.0
var shake := 0.0
var flash := 0.0
var pop := 0.0
var pop_pos := Vector2.ZERO
var pulse := 0.0

@onready var hud: Control = $HUD

func _ready() -> void:
	best = _load_best()
	hud.set_score(score)
	hud.set_best(best)
	_reset()

func _process(delta: float) -> void:
	pulse += delta
	accumulator += delta
	if state == "playing" and accumulator >= step_time:
		accumulator = 0.0
		_advance()
	shake = maxf(0.0, shake - delta * 20.0)
	flash = maxf(0.0, flash - delta)
	pop = maxf(0.0, pop - delta * 2.0)
	queue_redraw()
	hud.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_start()
		return
	var dir := Vector2i.ZERO
	if event.is_action_pressed("up"):
		dir = Vector2i.UP
	elif event.is_action_pressed("down"):
		dir = Vector2i.DOWN
	elif event.is_action_pressed("left"):
		dir = Vector2i.LEFT
	elif event.is_action_pressed("right"):
		dir = Vector2i.RIGHT
	if dir == Vector2i.ZERO or dir + direction == Vector2i.ZERO:
		return
	queued_direction = dir
	_start()
	get_viewport().set_input_as_handled()

func _start() -> void:
	if state == "over":
		_reset()
	state = "playing"
	hud.hide_message()

func _reset() -> void:
	body = [Vector2i(5, 10), Vector2i(4, 10), Vector2i(3, 10)]
	direction = Vector2i.RIGHT
	queued_direction = Vector2i.RIGHT
	score = 0
	step_time = BASE_STEP
	accumulator = 0.0
	_place_food()
	hud.set_score(score)

func _advance() -> void:
	direction = queued_direction
	var head: Vector2i = body[0] + direction
	var next := Vector2i(wrapi(head.x, 0, GRID_W), wrapi(head.y, 0, GRID_H))
	if next in body:
		_crash()
		return
	body.insert(0, next)
	if next == food:
		score += 10
		step_time = maxf(MIN_STEP, BASE_STEP - float(score) * 0.0012)
		shake = 6.0
		pop = 1.0
		pop_pos = cell_to_world(next)
		hud.set_score(score)
		_place_food()
	else:
		body.remove_at(body.size() - 1)

func _crash() -> void:
	state = "over"
	flash = 0.12
	if score > best:
		best = score
		_save_best()
		hud.set_best(best)
	hud.show_message("CRASHED\nScore %d  —  R to restart" % score, Palette.DANGER)

func _place_food() -> void:
	var free: Array[Vector2i] = []
	for y in GRID_H:
		for x in GRID_W:
			var c := Vector2i(x, y)
			if c not in body:
				free.append(c)
	if free.is_empty():
		return
	food = free[randi() % free.size()]

func cell_size() -> float:
	var vp := get_viewport_rect().size
	var avail := minf(vp.x, vp.y - HUD_H)
	return floorf(avail * 0.94 / float(mini(GRID_W, GRID_H)))

func board_origin() -> Vector2:
	var vp := get_viewport_rect().size
	var s := cell_size()
	return Vector2(
		floorf((vp.x - s * float(GRID_W)) * 0.5),
		floorf(HUD_H + (vp.y - HUD_H - s * float(GRID_H)) * 0.5))

func cell_to_world(c: Vector2i) -> Vector2:
	return board_origin() + (Vector2(c) + Vector2(0.5, 0.5)) * cell_size()

func _load_best() -> int:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var v := f.get_as_text().strip_edges()
	f.close()
	return int(v) if v.is_valid_int() else 0

func _save_best() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(str(best))
		f.close()

func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Palette.BACKGROUND)
	var s := cell_size()
	var origin := board_origin()
	var board_rect := Rect2(origin - Vector2(14, 14), Vector2(s * GRID_W, s * GRID_H) + Vector2(28, 28))
	draw_rect(board_rect.grow(8), Color(0, 0, 0, 0.35), true)
	draw_rect(board_rect, Palette.SURFACE, true)
	for x in GRID_W + 1:
		var gx := origin.x + s * x
		draw_line(Vector2(gx, origin.y), Vector2(gx, origin.y + s * GRID_H), Palette.GRID, 1.0)
	for y in GRID_H + 1:
		var gy := origin.y + s * y
		draw_line(Vector2(origin.x, gy), Vector2(origin.x + s * GRID_W, gy), Palette.GRID, 1.0)
	draw_rect(board_rect, Color(Palette.PRIMARY, 0.35), false, 2.0)

	var offset := Vector2.ZERO
	if shake > 0.0:
		offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))

	_draw_food(offset, s)
	_draw_snake(offset, s)

	if pop > 0.0:
		var col := Palette.ACCENT
		col.a = pop
		var font := ThemeDB.fallback_font
		draw_string(font, pop_pos + offset - Vector2(18, 0), "+10",
			HORIZONTAL_ALIGNMENT_CENTER, 36, 24, col)

	if flash > 0.0:
		var f := Color(Palette.DANGER, clampf(flash / 0.12, 0.0, 1.0) * 0.35)
		draw_rect(Rect2(Vector2.ZERO, vp), f, true)

func _draw_food(offset: Vector2, s: float) -> void:
	var c := cell_to_world(food) + offset
	var glow := 0.5 + 0.5 * sin(pulse * 5.0)
	draw_circle(c, s * 0.42, Color(Palette.ACCENT, 0.12 + 0.12 * glow))
	draw_circle(c, s * 0.26, Palette.ACCENT)
	draw_circle(c - Vector2(s * 0.08, s * 0.08), s * 0.09, Color(1, 1, 1, 0.7))

func _draw_snake(offset: Vector2, s: float) -> void:
	for i in range(body.size() - 1, -1, -1):
		var p := cell_to_world(body[i]) + offset
		var r := s * (0.44 if i == 0 else 0.36)
		var col := Palette.HEAD if i == 0 else Palette.PRIMARY
		draw_circle(p + Vector2(0, 2), r, Color(0, 0, 0, 0.35))
		draw_circle(p, r, col)
		if i == 0:
			var eye := direction
			var side := Vector2(-eye.y, eye.x)
			draw_circle(p + side * r * 0.35 - eye * r * 0.25, s * 0.07, Palette.BACKGROUND)
			draw_circle(p - side * r * 0.35 - eye * r * 0.25, s * 0.07, Palette.BACKGROUND)
