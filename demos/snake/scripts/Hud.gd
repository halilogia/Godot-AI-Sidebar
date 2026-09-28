class_name Hud
extends Control
## HUD bar (y 0..128) + centre overlays. Never overlaps the board.

var score_label: Label
var best_label: Label
var banner: Label
var hint: Label

func _ready() -> void:
	theme = _build_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	var bar := PanelContainer.new()
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1280, 128)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", _panel(Palette.SURFACE, 0, 0, 0))
	add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	bar.add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	var title := _label("SNAKE", 40, Palette.PRIMARY)
	var sub := _label("neon dusk", 18, Palette.TEXT_DIM)
	left.add_child(title)
	left.add_child(sub)
	row.add_child(left)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	var score_caption := _label("SCORE", 18, Palette.TEXT_DIM)
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(score_caption)
	score_label = _label("0", 26, Palette.TEXT)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best_label = _label("BEST 0", 18, Palette.ACCENT)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(score_label)
	right.add_child(best_label)
	row.add_child(right)

	banner = _label("", 40, Palette.DANGER)
	banner.position = Vector2(0, 300)
	banner.size = Vector2(1280, 60)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.visible = false
	add_child(banner)

	hint = _label("WASD / Arrows to steer  •  R to restart  •  Esc to quit", 18, Palette.TEXT_DIM)
	hint.position = Vector2(0, 668)
	hint.size = Vector2(1280, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func set_score(v: int) -> void:
	score_label.text = str(v)

func set_best(v: int) -> void:
	best_label.text = "BEST %d" % v

func show_banner(text: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = text != ""

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.BG_DEEP)
	l.add_theme_constant_override("outline_size", 5)
	return l

func _panel(bg: Color, radius: int, border: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if border > 0:
		sb.border_color = Palette.BORDER
		sb.set_border_width_all(border)
	if pad > 0:
		sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad + 24
	sb.content_margin_right = pad + 24
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb

func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var btn := _panel(Palette.SURFACE_LIGHT, 14, 1, 6)
	var hover := btn.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.PRIMARY_DARK
	for s in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", s, btn)
		t.set_stylebox("hover", s, hover)
		t.set_stylebox("pressed", s, hover)
		t.set_stylebox("focus", s, StyleBoxEmpty.new())
		t.set_color("font_color", s, Palette.TEXT)
		t.set_color("font_hover_color", s, Palette.PRIMARY)
	return t
