extends Control

const CARD_MIN := 2
const CARD_MAX := 11

var deck: Array[int] = []
var current: int = 0
var revealed: int = 0
var score: int = 0
var streak: int = 0
var round: int = 1
var locked: bool = false
var best: int = 0

var lbl_round: Label
var lbl_score: Label
var lbl_streak: Label
var card_face: Label
var card_suit: Label
var card_back: Label
var card: Panel
var lbl_prompt: Label
var btn_high: Button
var btn_low: Button
var btn_restart: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_hud()
	_build_card()
	_build_buttons()
	_new_deck()
	_start_round()


# ---------------------------------------------------------------- construction
func _build_background() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Palette.BG_DEEP)
	grad.set_color(1, Palette.BG_SOFT)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.2, 0.0)
	tex.fill_to = Vector2(0.8, 1.0)
	var bg := TextureRect.new()
	bg.texture = tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)

	var felt := Panel.new()
	felt.set_anchors_preset(Control.PRESET_FULL_RECT)
	felt.offset_top = 96
	felt.offset_bottom = -180
	felt.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.12), 14, Color(Palette.GOLD, 0.35), 2))
	add_child(felt)


func _build_hud() -> void:
	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 72)
	bar.offset_bottom = 72
	bar.add_theme_stylebox_override("panel", _box(Palette.BG_DEEP, 0, Palette.GOLD, 2))
	add_child(bar)

	var title := Label.new()
	title.text = "GUESS HIGHER"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Palette.GOLD)
	title.position = Vector2(28, 14)
	bar.add_child(title)

	lbl_round = _hud_label(bar, Vector2(360, 26), 22)
	lbl_score = _hud_label(bar, Vector2(560, 26), 22)
	lbl_streak = _hud_label(bar, Vector2(760, 26), 22)


func _hud_label(parent: Node, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Palette.PAPER)
	parent.add_child(l)
	return l


func _build_card() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.offset_top = 96
	holder.offset_bottom = -132
	add_child(holder)

	var c := Panel.new()
	c.custom_minimum_size = Vector2(300, 330)
	c.pivot_offset = Vector2(150, 165)
	c.add_theme_stylebox_override("panel", _box(Palette.PAPER, 14, Palette.GOLD, 3))
	holder.add_child(c)
	card = c

	card_face = Label.new()
	card_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_face.add_theme_font_size_override("font_size", 110)
	card_face.add_theme_color_override("font_color", Palette.INK)
	card.add_child(card_face)

	card_suit = Label.new()
	card_suit.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_suit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_suit.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	card_suit.offset_bottom = -16
	card_suit.add_theme_font_size_override("font_size", 26)
	card_suit.add_theme_color_override("font_color", Palette.INK)
	card.add_child(card_suit)

	card_back = Label.new()
	card_back.text = "?"
	card_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_back.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_back.add_theme_font_size_override("font_size", 140)
	card_back.add_theme_color_override("font_color", Palette.BG_SOFT)
	card.add_child(card_back)

	_set_card_face(true)


func _build_buttons() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -120
	row.offset_bottom = -24
	row.offset_left = 24
	row.offset_right = -24
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	add_child(row)

	btn_low = _button(row, "DAHA DÜŞÜK", Palette.GOLD)
	btn_high = _button(row, "DAHA YÜKSEK", Palette.GOLD)
	btn_low.pressed.connect(_on_low)
	btn_high.pressed.connect(_on_high)

	btn_restart = _button(row, "YENİ", Palette.BG_SOFT)
	btn_restart.add_theme_color_override("font_color", Palette.PAPER)
	btn_restart.pressed.connect(_on_restart)

	lbl_prompt = Label.new()
	lbl_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl_prompt.offset_top = -166
	lbl_prompt.offset_bottom = -128
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_prompt.add_theme_font_size_override("font_size", 18)
	lbl_prompt.add_theme_color_override("font_color", Palette.PAPER)
	add_child(lbl_prompt)


func _button(parent: Node, text: String, bg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 72)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Palette.INK)
	b.add_theme_color_override("font_hover_color", Palette.INK)
	b.add_theme_color_override("font_pressed_color", Palette.INK)
	var normal := _box(bg, 12, Palette.GOLD, 2)
	var hover := _box(bg.lightened(0.12), 12, Palette.GOLD, 2)
	var pressed := _box(bg.darkened(0.15), 12, Palette.GOLD, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	parent.add_child(b)
	return b


func _box(bg: Color, radius: int, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = 16
	s.content_margin_right = 16
	return s


# ------------------------------------------------------------------- game flow
func _new_deck() -> void:
	deck.clear()
	for i in range(CARD_MIN, CARD_MAX + 1):
		deck.append(i)
	deck.shuffle()


func _start_round() -> void:
	if deck.is_empty():
		_new_deck()
	current = deck.pop_back()
	revealed = 0
	locked = false
	_set_card_face(false)
	btn_low.disabled = false
	btn_high.disabled = false
	_slide_in()
	_refresh_hud()
	lbl_prompt.text = "Sıradaki kart %d'den yüksek mi, düşük mü?" % current


func _on_high() -> void:
	_guess(true)


func _on_low() -> void:
	_guess(false)


func _guess(higher: bool) -> void:
	if locked:
		return
	locked = true
	btn_low.disabled = true
	btn_high.disabled = true

	if deck.is_empty():
		_new_deck()
	revealed = deck.pop_back()
	_set_card_value(revealed)

	var correct: bool = (revealed > current) if higher else (revealed < current)
	if correct:
		score += 10 + streak * 2
		streak += 1
		best = maxi(best, streak)
		lbl_prompt.add_theme_color_override("font_color", Palette.GOLD)
		lbl_prompt.text = "Doğru! +%d" % (10 + (streak - 1) * 2)
		_flash(Palette.GOLD)
	else:
		streak = 0
		lbl_prompt.add_theme_color_override("font_color", Palette.DANGER)
		lbl_prompt.text = "Yanlış — kart %d'di." % revealed
		_shake()

	round += 1
	_refresh_hud()
	await get_tree().create_timer(0.7).timeout
	if is_inside_tree():
		_start_round()


func _on_restart() -> void:
	score = 0
	streak = 0
	round = 1
	_new_deck()
	_start_round()


func _refresh_hud() -> void:
	lbl_round.text = "Tur  %d" % round
	lbl_score.text = "Skor  %d" % score
	lbl_streak.text = "Seri  %d   En iyi  %d" % [streak, best]


# ---------------------------------------------------------------------- visuals
func _set_card_face(hidden: bool) -> void:
	card_face.visible = not hidden
	card_suit.visible = not hidden
	card_back.visible = hidden
	card_face.text = str(current)
	card_suit.text = _suit(current)


func _set_card_value(v: int) -> void:
	card_face.text = str(v)
	card_suit.text = _suit(v)


func _suit(v: int) -> String:
	if v <= 4:
		return "DAMLA"
	elif v <= 7:
		return "YAPRAK"
	return "GÜNEŞ"


func _slide_in() -> void:
	if card == null:
		return
	card.scale = Vector2(0.92, 0.92)
	card.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)


func _flash(c: Color) -> void:
	if card == null:
		return
	var tw := create_tween()
	tw.tween_property(card, "modulate", c, 0.06)
	tw.tween_property(card, "modulate", Color.WHITE, 0.12)


func _shake() -> void:
	if card == null:
		return
	var home := card.position
	var tw := create_tween()
	for off in [6.0, -6.0, 4.0, -4.0, 0.0]:
		tw.tween_property(card, "position", home + Vector2(off, 0), 0.03)
