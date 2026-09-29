extends Control

const TOP_H := 96.0
const BOT_H := 176.0

var battle: Battle
var units: Array[Combatant] = []
var title_lbl: Label
var turn_lbl: Label
var log_lbl: RichTextLabel
var hint_lbl: Label
var menu: HBoxContainer
var field: Control
var shake := 0.0
var result_panel: PanelContainer
var result_lbl: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	battle = Battle.new()
	add_child(battle)
	battle.log_line.connect(_on_log)
	battle.damage_shown.connect(_on_damage)
	battle.battle_over.connect(_on_over)
	battle.state_changed.connect(_on_state)
	_spawn()
	battle.start()
	set_process(true)

func _on_state(_s: int) -> void:
	if battle.state == Battle.State.ENEMY_TURN:
		var t := get_tree().create_timer(0.9)
		t.timeout.connect(func(): battle.run_enemy_turn())

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grad := TextureRect.new()
	grad.texture = _gradient()
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(grad)

	title_lbl = _label("TASI ZINDAN", 32, Palette.PRIMARY)
	title_lbl.position = Vector2(28, 14)
	add_child(title_lbl)

	turn_lbl = _label("", 22, Palette.ACCENT)
	turn_lbl.anchor_left = 1.0
	turn_lbl.anchor_right = 1.0
	turn_lbl.offset_left = -340
	turn_lbl.offset_right = -30
	turn_lbl.offset_top = 22
	turn_lbl.offset_bottom = 54
	turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(turn_lbl)

	field = Control.new()
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.position = Vector2(0, TOP_H)
	field.size = Vector2(1280, 720 - TOP_H - BOT_H)
	add_child(field)

	# bottom bar
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", Palette.panel_style(Palette.SURFACE, Palette.SURFACE_RAISED))
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 0
	bar.offset_right = 0
	bar.offset_top = -BOT_H
	bar.offset_bottom = 0
	add_child(bar)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	bar.add_child(v)

	log_lbl = RichTextLabel.new()
	log_lbl.bbcode_enabled = true
	log_lbl.fit_content = true
	log_lbl.scroll_active = false
	log_lbl.custom_minimum_size = Vector2(0, 54)
	log_lbl.add_theme_font_size_override("normal_font_size", 16)
	log_lbl.add_theme_color_override("default_color", Palette.PRIMARY)
	v.add_child(log_lbl)

	menu = HBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	v.add_child(menu)
	_make_button("SALDIR", Palette.ACCENT, func(): _cmd("attack"))
	_make_button("BECERİ (6 MP)", Color("#C9A227"), func(): _cmd("skill"))
	_make_button("KALKAN", Palette.PRIMARY, func(): _cmd("guard"))

	hint_lbl = _label("", 16, Palette.PRIMARY)
	hint_lbl.position = Vector2(28, 62)
	hint_lbl.size = Vector2(900, 26)
	add_child(hint_lbl)

	result_panel = PanelContainer.new()
	result_panel.add_theme_stylebox_override("panel", Palette.panel_style(Palette.SURFACE_RAISED, Palette.ACCENT))
	result_panel.size = Vector2(460, 160)
	result_panel.position = Vector2(410, 250)
	result_panel.visible = false
	add_child(result_panel)
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	result_panel.add_child(rv)
	result_lbl = _label("ZAFER", 32, Palette.ACCENT)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(result_lbl)
	var again := Button.new()
	again.text = "YENİ SAVAŞ"
	_style_button(again, Palette.ACCENT)
	again.pressed.connect(_restart)
	rv.add_child(again)

func _gradient() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color("#241A15"))
	g.set_color(1, Color("#0C0A09"))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 8
	t.height = 128
	return t

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0,0,0,0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _style_button(b: Button, accent: Color) -> void:
	var normal := Palette.panel_style(Palette.SURFACE_RAISED, accent)
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := Palette.panel_style(Color("#4A3C35"), accent)
	var pressed := Palette.panel_style(Color(accent.r, accent.g, accent.b, 0.35), accent)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", Palette.PRIMARY)
	b.add_theme_color_override("font_hover_color", Palette.ACCENT)
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(180, 46)

func _make_button(text: String, accent: Color, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	_style_button(b, accent)
	b.pressed.connect(cb)
	menu.add_child(b)

func _spawn() -> void:
	var defs := [
		["Korsan", 70, 24, 14, 5, true, 0],
		["Büyücü", 46, 40, 10, 2, true, 1],
		["Gölge", 54, 20, 15, 4, false, 5],
		["Goblin", 48, 8, 12, 3, false, 3],
		["Brüt", 78, 6, 18, 6, false, 2],
		["Şaman", 44, 26, 11, 3, false, 4],
	]
	var area := field.size
	var spots := [Vector2(0.20, 0.32), Vector2(0.20, 0.70),
		Vector2(0.60, 0.22), Vector2(0.60, 0.68),
		Vector2(0.85, 0.22), Vector2(0.85, 0.68)]
	for i in defs.size():
		var d: Array = defs[i]
		var c := Combatant.new()
		c.cname = d[0]
		c.max_hp = d[1]
		c.hp = d[1]
		c.max_mp = d[2]
		c.mp = d[2]
		c.attack = d[3]
		c.defense = d[4]
		c.is_player = d[5]
		c.shape = d[6]
		var s: Vector2 = spots[i]
		c.position = Vector2(area.x * s.x, area.y * s.y)
		field.add_child(c)
		units.append(c)
		battle.combatants.append(c)
		battle.order.append(c)
		c.stats_changed.connect(func(_x): battle.stats_changed.emit())

func _restart() -> void:
	for c in units:
		c.queue_free()
	units.clear()
	battle = null
	get_tree().reload_current_scene()

func _cmd(kind: String) -> void:
	var c := battle.current()
	if battle.state != Battle.State.PLAYER_TURN or c == null or not c.is_player:
		return
	if kind == "skill" and c.mp < 6:
		log_lbl.text += "\n[color=#C4453C]Yeterli mana yok.</color>"
		return
	var enemies := battle.living(false)
	if enemies.is_empty():
		return
	var target: Combatant = enemies[0]
	battle.player_action(c, target, kind, 0)

func _process(delta: float) -> void:
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 30.0)
		field.position = Vector2(randf_range(-shake, shake), TOP_H + randf_range(-shake, shake))
	var c: Combatant = battle.current() if battle else null
	for u in units:
		u.active = (u == c)
		u.queue_redraw()
	if battle.state == Battle.State.OVER:
		turn_lbl.text = ""
	else:
		turn_lbl.text = ("SIRA: " + c.cname) if c else ""
	_set_buttons(c != null and battle.state == Battle.State.PLAYER_TURN and c.is_player)
	if c != null:
		hint_lbl.text = "%s | HP %d/%d  MP %d/%d  ATK %d" % [c.cname, c.hp, c.max_hp, c.mp, c.max_mp, c.attack]

func _set_buttons(on: bool) -> void:
	for b in menu.get_children():
		(b as Button).disabled = not on

func _on_log(text: String) -> void:
	log_lbl.text += "\n[color=#E8D5B0]%s[/color]" % text

func _on_damage(world_pos: Vector2, amount: int, is_enemy: bool) -> void:
	shake = 5.0
	var l := _label(str(amount), 26, Palette.DANGER if is_enemy else Palette.ACCENT)
	l.position = world_pos + Vector2(-20, -30) - field.position
	l.z_index = 10
	field.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(l.queue_free)

func _on_over(win: bool) -> void:
	result_panel.visible = true
	result_lbl.text = "ZAFER" if win else "YENİLDİN"
	result_lbl.add_theme_color_override("font_color", Palette.ACCENT if win else Palette.DANGER)
