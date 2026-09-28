extends Control
class_name UIRoot

## Builds the whole HUD procedurally (no .tscn UI nodes) so the theme,
## fonts and spacing stay in one place.

var distance_label: Label
var coin_label: Label
var best_label: Label
var title_panel: PanelContainer
var gameover_panel: PanelContainer
var go_score: Label
var go_coins: Label
var go_best: Label
var flash_rect: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _panel(bg: Color, radius: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(2)
	sb.border_color = Palette.with_alpha(Palette.PRIMARY, 0.35)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 20.0
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.OUTLINE)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _center(p: Control, top: float) -> void:
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.position = Vector2(0.0, top)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_END


func _build() -> void:
	flash_rect = ColorRect.new()
	flash_rect.color = Color(0, 0, 0, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash_rect)

	# --- top HUD bar ---
	var top := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.OUTLINE, 0.55)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	top.add_theme_stylebox_override("panel", sb)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24.0
	top.offset_right = -24.0
	top.offset_top = 18.0
	add_child(top)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)

	distance_label = _label("0 m", 22, Palette.PRIMARY)
	coin_label = _label("●  0", 22, Palette.ACCENT)
	best_label = _label("EN İYİ  0 m", 22, Palette.TEXT)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(distance_label)
	row.add_child(coin_label)
	row.add_child(spacer)
	row.add_child(best_label)

	# --- title ---
	title_panel = _panel(Palette.with_alpha(Palette.SURFACE, 0.92))
	_center(title_panel, 190.0)
	add_child(title_panel)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 10)
	title_panel.add_child(tv)
	tv.add_child(_label("NEON DASH", 40, Palette.PRIMARY))
	tv.add_child(_label("SPACE / W / UP  →  zıpla", 16, Palette.TEXT))
	tv.add_child(_label("S / DOWN  →  eğil     P  →  duraklat", 16, Palette.TEXT))
	var hint := _label("Başlamak için bir tuşa bas", 22, Palette.ACCENT)
	tv.add_child(hint)

	# --- game over ---
	gameover_panel = _panel(Palette.with_alpha(Palette.SURFACE, 0.95))
	_center(gameover_panel, 200.0)
	add_child(gameover_panel)
	var gv := VBoxContainer.new()
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gv.add_theme_constant_override("separation", 8)
	gameover_panel.add_child(gv)
	gv.add_child(_label("YENİLDİN", 40, Palette.DANGER))
	go_score = _label("MESAFE  0 m", 24, Palette.PRIMARY)
	go_coins = _label("COIN  0", 22, Palette.ACCENT)
	go_best = _label("EN İYİ  0 m", 22, Palette.TEXT)
	gv.add_child(go_score)
	gv.add_child(go_coins)
	gv.add_child(go_best)
	gv.add_child(_label("Yeniden oynamak için bir tuşa bas", 16, Palette.TEXT))
	gameover_panel.visible = false
