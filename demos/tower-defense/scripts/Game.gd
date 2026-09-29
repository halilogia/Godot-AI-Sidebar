class_name Game
extends Node2D

const HUD_H := 64.0
const MARGIN := 14.0
const START_GOLD := 180
const LIVES := 20

var level: Level
var gold := START_GOLD
var lives := LIVES
var wave := 0
var selected := 0
var towers: Array[Tower] = []
var enemies: Array[Enemy] = []
var spawn_timer := 0.0
var wave_active := false
var spawn_left := 0
var spawn_gap := 0.0
var hp_scale := 1.0
var origin := Vector2.ZERO
var shake := 0.0
var hover := Vector2i(-1, -1)

@onready var world: Node2D = $World
@onready var hud: Control = $HUD
@onready var fx: Node2D = $Fx

var lbl_gold: Label
var lbl_lives: Label
var lbl_wave: Label
var hint: Label

func _ready() -> void:
	level = Level.build()
	origin = Vector2((1280.0 - level.field_size().x) * 0.5, HUD_H + MARGIN)
	world.position = origin
	_build_ui()
	_start_next_wave()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_bottom = HUD_H
	panel.add_theme_stylebox_override("panel", _bar_style())
	hud.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	panel.add_child(row)

	lbl_gold = _mk_label("ALTIN")
	lbl_lives = _mk_label("CAN")
	lbl_wave = _mk_label("DALGA")
	row.add_child(lbl_gold)
	row.add_child(lbl_lives)
	row.add_child(lbl_wave)

	for i in 3:
		var s: Dictionary = Tower.STATS[i]
		var b := Button.new()
		b.text = "%s  %d" % [s["name"], s["cost"]]
		b.add_theme_stylebox_override("normal", _btn_style(Palette.SURFACE, s["color"]))
		b.add_theme_stylebox_override("hover", _btn_style(Palette.SURFACE.lightened(0.15), s["color"]))
		b.add_theme_stylebox_override("pressed", _btn_style(s["color"].darkened(0.55), s["color"]))
		b.pressed.connect(_pick.bind(i))
		row.add_child(b)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var nb := Button.new()
	nb.text = "DALGA AT"
	nb.add_theme_stylebox_override("normal", _btn_style(Palette.ACCENT.darkened(0.45), Palette.ACCENT))
	nb.add_theme_stylebox_override("hover", _btn_style(Palette.ACCENT.darkened(0.3), Palette.ACCENT))
	nb.add_theme_stylebox_override("pressed", _btn_style(Palette.ACCENT.darkened(0.6), Palette.ACCENT))
	nb.pressed.connect(_start_next_wave)
	row.add_child(nb)

	hint = _mk_label("")
	row.add_child(hint)
	_update_hud()

func _mk_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Palette.TEXT)
	l.add_theme_color_override("font_outline_color", Palette.BG)
	l.add_theme_constant_override("outline_size", 4)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _bar_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.BG
	sb.border_color = Palette.PRIMARY.darkened(0.55)
	sb.border_width_bottom = 2
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	return sb

func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _start_next_wave() -> void:
	if wave_active:
		return
	wave += 1
	wave_active = true
	spawn_left = 6 + wave * 3
	spawn_gap = maxf(0.35, 0.9 - wave * 0.04)
	spawn_timer = 0.5
	hp_scale = 1.0 + (wave - 1) * 0.25
	fx.call("banner", "DALGA %d" % wave)
	_update_hud()

func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 12.0)
	world.position = origin + Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	if wave_active and spawn_left > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn()
			spawn_timer = spawn_gap
	if wave_active and spawn_left <= 0 and enemies.is_empty():
		wave_active = false
		gold += 20 + wave * 5
		_update_hud()
	var alive: Array[Tower] = []
	for t in towers:
		if is_instance_valid(t):
			t.fire(enemies)
			alive.append(t)
	towers = alive
	queue_redraw()

func _spawn() -> void:
	spawn_left -= 1
	var tanky := wave % 4 == 0
	var e := Enemy.new()
	e.setup(level, hp_scale * (1.7 if tanky else 1.0), 52.0 if tanky else 78.0, Palette.ACCENT if tanky else Palette.DANGER, 16.0 if tanky else 11.0)
	e.died.connect(_on_died)
	e.leaked.connect(_on_leaked)
	world.add_child(e)
	enemies.append(e)

func _on_died(e: Enemy) -> void:
	gold += e.reward
	fx.call("pop", e.global_position, "+%d" % e.reward, Palette.ACCENT)
	enemies.erase(e)
	shake = 3.0
	_update_hud()

func _on_leaked(e: Enemy) -> void:
	lives -= 1
	enemies.erase(e)
	shake = 5.0
	if lives <= 0:
		lives = 0
		fx.call("banner", "KAYBETTIN")
	_update_hud()

func _pick(i: int) -> void:
	selected = i
	_update_hud()

func _update_hud() -> void:
	lbl_gold.text = "ALTIN  %d" % gold
	lbl_lives.text = "CAN  %d" % lives
	lbl_wave.text = "DALGA  %d" % maxi(1, wave)
	var s: Dictionary = Tower.STATS[selected]
	hint.text = "%s — %s" % [s["name"], s["desc"]]

func _cell_at() -> Vector2i:
	var l := get_global_mouse_position() - world.position
	return Vector2i(floori(l.x / Level.CELL), floori(l.y / Level.CELL))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := _cell_at()
		if c != hover:
			hover = c
			queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c := _cell_at()
		if level.is_buildable(c):
			var s: Dictionary = Tower.STATS[selected]
			if gold >= s["cost"]:
				gold -= s["cost"]
				var t := Tower.new()
				t.setup(level, c, selected)
				t.fx = fx
				world.add_child(t)
				towers.append(t)
				_update_hud()

func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Palette.BG)
	var g := 64.0
	var gx := 0.0
	while gx < vs.x:
		draw_line(Vector2(gx, 0), Vector2(gx, vs.y), Palette.GRID, 1.0)
		gx += g
	var gy := 0.0
	while gy < vs.y:
		draw_line(Vector2(0, gy), Vector2(vs.x, gy), Palette.GRID, 1.0)
		gy += g

	var fs := level.field_size()
	draw_rect(Rect2(origin, fs), Palette.SURFACE)
	draw_rect(Rect2(origin, fs), Palette.PRIMARY.darkened(0.6), false, 2.0)

	for c in level.path_cells:
		var p: Vector2 = origin + level.world_pos(c)
		draw_rect(Rect2(p - Vector2(Level.CELL, Level.CELL) * 0.5, Vector2(Level.CELL, Level.CELL)), Palette.ROAD)
		draw_rect(Rect2(p - Vector2(Level.CELL, Level.CELL) * 0.5, Vector2(Level.CELL, Level.CELL)), Palette.ROAD_EDGE, false, 2.0)
	for c in level.path_cells:
		var p2: Vector2 = origin + level.world_pos(c)
		var nxt: Vector2 = p2 + (origin + level.world_pos(level.path_cells[mini(level.path_cells.find(c) + 1, level.path_cells.size() - 1)]) - p2).normalized() * 10.0
		draw_line(p2, nxt, Palette.ROAD_LINE, 3.0)

	for cy in Level.ROWS:
		for cx in Level.COLS:
			var c := Vector2i(cx, cy)
			if level.is_buildable(c):
				draw_circle(origin + level.world_pos(c), 2.0, Palette.GRID.lightened(0.35))

	draw_circle(origin + level.world_pos(level.spawn_cell), 16.0, Palette.DANGER.darkened(0.45))
	draw_circle(origin + level.world_pos(level.spawn_cell), 11.0, Palette.DANGER)
	draw_circle(origin + level.world_pos(level.base_cell), 19.0, Palette.PRIMARY.darkened(0.55))
	draw_circle(origin + level.world_pos(level.base_cell), 12.0, Palette.PRIMARY)

	if level.is_buildable(hover):
		var s: Dictionary = Tower.STATS[selected]
		var col: Color = s["color"]
		var ok: bool = gold >= int(s["cost"])
		var r := Rect2(origin + Vector2(hover.x, hover.y) * Level.CELL, Vector2(Level.CELL, Level.CELL))
		draw_rect(r, Color(col.r, col.g, col.b, 0.18 if ok else 0.08))
		draw_rect(r, col if ok else Palette.DANGER, false, 2.0)
