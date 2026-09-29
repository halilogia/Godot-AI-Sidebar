class_name Hud
extends CanvasLayer

var game: Game
var wave_label: Label
var gold_label: Label
var lives_label: Label
var info_label: Label
var start_label: Label
var wave_button: Button
var kind_buttons: Array = []
var end_panel: PanelContainer
var end_title: Label
var end_sub: Label
const FIELD_BOTTOM := 622.0
const BAR_TOP := 634.0

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top(root)
	_build_bottom(root)
	_build_overlay(root)

func _panel(w: float, h: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = Vector2(16.0, 12.0)
	p.custom_minimum_size = Vector2(1248.0, h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _build_top(root: Control) -> void:
	var panel := _panel(0, 60)
	root.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	panel.add_child(h)
	wave_label = _label("Dalga 0", 26)
	gold_label = _label("Altın 0", 26)
	lives_label = _label("Can 0", 26)
	h.add_child(wave_label)
	h.add_child(gold_label)
	h.add_child(lives_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	start_label = _label("", 16)
	start_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	h.add_child(start_label)

func _build_bottom(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, BAR_TOP)
	panel.custom_minimum_size = Vector2(1248.0, 70.0)
	root.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	for k: TowerData.Kind in [TowerData.Kind.ARCHER, TowerData.Kind.CANNON, TowerData.Kind.FROST]:
		var d: Dictionary = TowerData.DEFS[k]
		var b := _button("%s  %d" % [d["name"], d["cost"]])
		b.pressed.connect(func() -> void: _pick_kind(k))
		h.add_child(b)
		kind_buttons.append({"button": b, "kind": k})
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	info_label = _label("", 17)
	info_label.custom_minimum_size = Vector2(420.0, 0.0)
	h.add_child(info_label)
	kind_buttons.sort_custom(func(a, b): return int(a["kind"]) < int(b["kind"]))
	var up := _button("Yükselt")
	up.pressed.connect(func() -> void: _game_call("try_build"))
	h.add_child(up)
	var sell := _button("Sat")
	sell.pressed.connect(func() -> void: _game_call("sell_selected"))
	h.add_child(sell)
	wave_button = _button("Dalga Başlat  (Boşluk)")
	wave_button.pressed.connect(func() -> void: _game_call("start_wave"))
	h.add_child(wave_button)

func _build_overlay(root: Control) -> void:
	end_panel = PanelContainer.new()
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.custom_minimum_size = Vector2(560.0, 220.0)
	end_panel.visible = false
	root.add_child(end_panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	end_panel.add_child(v)
	end_title = _label("Oyun Bitti", 40)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_title)
	end_sub = _label("", 20)
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_sub)
	var again := _button("Yeniden Başla")
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	v.add_child(again)

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.TEXT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme = UiTheme.make()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_pressed_color", Palette.BG_DEEP)
	return b

func _game_call(method: String) -> void:
	if game != null:
		game.call(method)

func _pick_kind(k: TowerData.Kind) -> void:
	if game != null:
		game.set_build_kind(k)

func bind(g: Game) -> void:
	game = g
	g.stats_changed.connect(_on_stats)
	g.selection_changed.connect(_on_selection)
	g.game_over.connect(_on_game_over)
	_on_stats(g.gold, g.lives, g.wave)
	_on_selection({"mode": "none"})

func _on_stats(gold_v: int, lives_v: int, wave_v: int) -> void:
	wave_label.text = "Dalga %d" % wave_v
	gold_label.text = "Altın %d" % gold_v
	lives_label.text = "Can %d" % lives_v

func _on_selection(sel: Dictionary) -> void:
	match String(sel.get("mode", "none")):
		"build":
			info_label.text = "%s kur: %d altın · menzil %d · hasar %d" % [
				sel["name"], sel["cost"], int(sel["range"]), int(sel["damage"])]
			info_label.add_theme_color_override("font_color", Palette.ACCENT)
		"tower":
			info_label.text = "%s SvL%d · hasar %d · menzil %d" % [
				sel["name"], sel["level"], int(sel["damage"]), int(sel["range"])]
			info_label.add_theme_color_override("font_color", Palette.PRIMARY)
		_:
			info_label.text = "Kule kurmak için yol dışı boş bir kareye tıkla."
			info_label.add_theme_color_override("font_color", Palette.TEXT_DIM)

func _on_game_over(won: bool) -> void:
	end_panel.visible = true
	end_title.text = "Zafer!" if won else "Üs Düştü"
	end_sub.text = "Dalga %d" % game.wave
	start_label.text = ""
	wave_button.disabled = true
