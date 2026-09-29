extends Node2D

const CELL := 74.0
const BOARD_PX := CELL * Board.SIZE
const BOARD_ORIGIN := Vector2(344.0, 76.0)
const SWAP_TIME := 0.14
const FALL_TIME := 0.10
const CLEAR_TIME := 0.13

var board: Board
var rng := RandomNumberGenerator.new()
var gems: Dictionary = {}  # Vector2i -> Gem
var gem_root: Node2D
var selected := Vector2i(-1, -1)
var busy := false
var score := 0
var score_label: Label
var status_label: Label


func _ready() -> void:
	rng.randomize()
	board = Board.new()
	_build_background()
	_build_hud()
	board.fill_random(rng)
	while not board.has_valid_move():
		board.fill_random(rng)
	for y in Board.SIZE:
		for x in Board.SIZE:
			_spawn_gem(Vector2i(x, y), board.get_gem(x, y), true)

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG_DEEP
	bg.size = Vector2(1280, 720)
	bg.z_index = -10
	add_child(bg)
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Palette.BG_MID)
	g.set_color(1, Palette.BG_DEEP)
	grad.gradient = g
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.45)
	grad.fill_to = Vector2(1.0, 0.5)
	grad.width = 512
	grad.height = 512
	var glow := Sprite2D.new()
	glow.texture = grad
	glow.position = Vector2(640, 380)
	glow.scale = Vector2(3.2, 2.4)
	glow.z_index = -9
	add_child(glow)
	gem_root = Node2D.new()
	gem_root.name = "Gems"
	add_child(gem_root)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "CANDY DUSK"
	title.position = Vector2(40, 22)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Palette.TEXT)
	layer.add_child(title)

	var sub := Label.new()
	sub.text = "match 3 - build a cascade"
	sub.position = Vector2(44, 70)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Palette.TEXT_DIM)
	layer.add_child(sub)

	var panel := Panel.new()
	panel.position = Vector2(1000, 24)
	panel.size = Vector2(240, 76)
	panel.add_theme_stylebox_override("panel", _panel_style())
	layer.add_child(panel)

	score_label = Label.new()
	score_label.text = "SCORE 0"
	score_label.position = Vector2(1000, 42)
	score_label.size = Vector2(240, 40)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Palette.ACCENT)
	layer.add_child(score_label)

	status_label = Label.new()
	status_label.text = "Pick two neighbours to swap"
	status_label.position = Vector2(320, 676)
	status_label.size = Vector2(640, 28)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	layer.add_child(status_label)

	var hint := Label.new()
	hint.text = "R  reshuffle"
	hint.position = Vector2(1092, 668)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Palette.TEXT_DIM)
	layer.add_child(hint)


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Palette.CELL.r, Palette.CELL.g, Palette.CELL.b, 0.92)
	s.set_corner_radius_all(14)
	s.border_color = Palette.CELL_HI
	s.set_border_width_all(2)
	return s


func _draw() -> void:
	pass


func cell_center(x: int, y: int) -> Vector2:
	return BOARD_ORIGIN + Vector2(x * CELL + CELL * 0.5, y * CELL + CELL * 0.5)


func _spawn_gem(pos: Vector2i, type: int, pop: bool = false) -> Gem:
	var g := Gem.new()
	g.position = cell_center(pos.x, pos.y)
	gem_root.add_child(g)
	g.setup(type)
	gems[pos] = g
	if pop:
		g.scale = Vector2.ZERO
		var t := g.create_tween()
		t.tween_property(g, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return g


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click(get_global_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reshuffle()


func _on_click(pos: Vector2) -> void:
	if busy:
		return
	var lx := int(floor((pos.x - BOARD_ORIGIN.x) / CELL))
	var ly := int(floor((pos.y - BOARD_ORIGIN.y) / CELL))
	if lx < 0 or ly < 0 or lx >= Board.SIZE or ly >= Board.SIZE:
		return
	var cell := Vector2i(lx, ly)
	if selected.x < 0:
		_select(cell)
	elif selected == cell:
		_select(Vector2i(-1, -1))
	elif abs(selected.x - cell.x) + abs(selected.y - cell.y) == 1:
		var from := selected
		_select(Vector2i(-1, -1))
		_try_swap(from, cell)
	else:
		_select(cell)


func _select(cell: Vector2i) -> void:
	if selected.x >= 0 and gems.has(selected):
		gems[selected].selected = false
		gems[selected].queue_redraw()
	selected = cell
	if cell.x >= 0 and gems.has(cell):
		gems[cell].selected = true
		gems[cell].queue_redraw()


func _try_swap(a: Vector2i, b: Vector2i) -> void:
	busy = true
	var ga: Gem = gems[a]
	var gb: Gem = gems[b]
	board.swap(a, b)
	gems[a] = gb
	gems[b] = ga
	_animate(ga, cell_center(b.x, b.y), SWAP_TIME)
	_animate(gb, cell_center(a.x, a.y), SWAP_TIME)
	await get_tree().create_timer(SWAP_TIME).timeout
	if board.find_matches().is_empty():
		board.swap(a, b)
		gems[a] = ga
		gems[b] = gb
		_animate(ga, cell_center(a.x, a.y), SWAP_TIME)
		_animate(gb, cell_center(b.x, b.y), SWAP_TIME)
		await get_tree().create_timer(SWAP_TIME).timeout
		_set_status("No match there - swapped back", Palette.DANGER)
		await get_tree().create_timer(0.9).timeout
		_set_status("Pick two neighbours to swap", Palette.TEXT_DIM)
		busy = false
		return
	await _resolve_cascades()


func _resolve_cascades() -> void:
	var cascade := 0
	while true:
		var matches := board.find_matches()
		if matches.is_empty():
			break
		cascade += 1
		score += matches.size() * 10 * cascade
		_update_score()
		var clearing: Array[Gem] = []
		for c in matches:
			if gems.has(c):
				clearing.append(gems[c])
				gems.erase(c)
		for g in clearing:
			_burst(g.position, Palette.GEM_COLORS[g.type % Palette.GEM_COLORS.size()])
		for g in clearing:
			g.modulate = Color(1.7, 1.7, 1.7, 0.15)
			var t := g.create_tween()
			t.tween_property(g, "scale", Vector2(0.2, 0.2), CLEAR_TIME)
		await get_tree().create_timer(CLEAR_TIME).timeout
		for g in clearing:
			g.queue_free()
		for c in matches:
			board.set_gem(c.x, c.y, -1)
		if cascade > 1:
			_set_status("Cascade x%d!" % cascade, Palette.ACCENT)
		await _apply_fall()
	if not board.has_valid_move():
		await _reshuffle()
	busy = false


func _apply_fall() -> void:
	var result := board.apply_gravity()
	var moves: Dictionary = result["moves"]
	var spawns: Dictionary = result["spawns"]
	var longest := FALL_TIME
	for from in moves.keys():
		var to: Vector2i = moves[from]
		var g: Gem = gems[from]
		gems.erase(from)
		gems[to] = g
		_animate(g, cell_center(to.x, to.y), FALL_TIME)
	for x in spawns.keys():
		var count: int = spawns[x]
		for i in count:
			var type := rng.randi() % Palette.GEM_COLORS.size()
			board.set_gem(int(x), i, type)
			var pos := Vector2i(int(x), i)
			var g := _spawn_gem(pos, type, false)
			var dur := FALL_TIME * float(count - i + 1)
			g.position = cell_center(pos.x, pos.y) - Vector2(0, CELL * float(count - i + 1))
			_animate(g, cell_center(pos.x, pos.y), dur)
			longest = maxf(longest, dur)
	await get_tree().create_timer(longest).timeout


func _reshuffle() -> void:
	if busy:
		return
	busy = true
	_set_status("No moves left - reshuffling", Palette.DANGER)
	for key in gems.keys():
		var g: Gem = gems[key]
		var t := g.create_tween()
		t.tween_property(g, "scale", Vector2.ZERO, 0.18)
	await get_tree().create_timer(0.2).timeout
	for key in gems.keys():
		gems[key].queue_free()
	gems.clear()
	while true:
		board.fill_random(rng)
		if board.has_valid_move():
			break
	for y in Board.SIZE:
		for x in Board.SIZE:
			_spawn_gem(Vector2i(x, y), board.get_gem(x, y), true)
	_set_status("Pick two neighbours to swap", Palette.TEXT_DIM)
	busy = false


func _animate(g: Node2D, to: Vector2, time: float) -> void:
	var t := g.create_tween()
	t.tween_property(g, "position", to, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _burst(pos: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 10
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.35
	p.spread = 180.0
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 150.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	p.emitting = true
	gem_root.add_child(p)
	var t := get_tree().create_timer(0.7)
	t.timeout.connect(p.queue_free)


func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


func _update_score() -> void:
	score_label.text = "SCORE %d" % score
