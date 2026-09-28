class_name CardGame
extends Control

const HAND_SIZE := 5
const CARD_SIZE := Vector2(104, 156)

@onready var _hand_row: HBoxContainer = $HandRow
@onready var _opp_row: HBoxContainer = $OpponentRow
@onready var _score_label: Label = $HUD/Margin/Row/ScoreLabel
@onready var _deck_label: Label = $HUD/Margin/Row/DeckLabel
@onready var _info: Label = $Info
@onready var _play_button: Button = $PlayButton
@onready var _table: Panel = $Table

var _deck: Array[Dictionary] = []
var _player_hand: Array[Dictionary] = []
var _opponent_hand: Array[Dictionary] = []
var _hand_views: Array[CardView] = []
var _opp_views: Array[CardView] = []
var _selected := -1
var _busy := false
var _player_score := 0
var _opponent_score := 0


func _ready() -> void:
	_build_theme()
	_play_button.pressed.connect(_on_play_pressed)
	_start_round()


func _build_theme() -> void:
	var theme := Theme.new()
	theme.default_font_size = 16
	var panel := StyleBoxFlat.new()
	panel.bg_color = Palette.SURFACE
	panel.set_corner_radius_all(10)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Palette.PRIMARY
	btn.set_corner_radius_all(10)
	btn.content_margin_top = 10
	btn.content_margin_bottom = 10
	btn.content_margin_left = 22
	btn.content_margin_right = 22
	btn.shadow_color = Color(0, 0, 0, 0.35)
	btn.shadow_size = 4
	btn.shadow_offset = Vector2(0, 3)
	var btn_hover := btn.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Palette.PRIMARY.lightened(0.14)
	var btn_pressed := btn.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Palette.PRIMARY.darkened(0.2)
	btn_pressed.shadow_size = 0
	var btn_disabled := btn.duplicate() as StyleBoxFlat
	btn_disabled.bg_color = Color(Palette.PRIMARY, 0.3)
	btn_disabled.shadow_size = 0
	var felt := panel.duplicate() as StyleBoxFlat
	felt.bg_color = Palette.SURFACE_LIGHT.darkened(0.15)
	felt.border_color = Palette.PRIMARY.darkened(0.45)
	felt.set_border_width_all(2)
	felt.shadow_color = Color(0, 0, 0, 0.3)
	felt.shadow_size = 6
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", felt)
	theme.set_stylebox("normal", "Button", btn)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color", "Button", Palette.TEXT_DARK)
	theme.set_color("font_hover_color", "Button", Palette.TEXT_DARK)
	theme.set_color("font_pressed_color", "Button", Palette.TEXT_DARK)
	theme.set_color("font_disabled_color", "Button", Color(Palette.TEXT_DARK, 0.5))
	theme.set_font_size("font_size", "Button", 20)
	self.theme = theme


func _start_round() -> void:
	_deck = CardData.make_deck()
	_deck.shuffle()
	_player_hand.clear()
	_opponent_hand.clear()
	for i in HAND_SIZE:
		_player_hand.append(_deck.pop_back())
		_opponent_hand.append(_deck.pop_back())
	_selected = -1
	_busy = false
	_play_button.disabled = false
	_play_button.text = "Oyna"
	_info.text = "Bir kart seç, sonra Oyna."
	_rebuild_views()


func _rebuild_views() -> void:
	for c in _hand_row.get_children():
		c.queue_free()
	for c in _opp_row.get_children():
		c.queue_free()
	_hand_views.clear()
	_opp_views.clear()
	for card in _player_hand:
		var v := _make_view(card)
		_hand_row.add_child(v)
		_hand_views.append(v)
	for i in _opponent_hand.size():
		var v := _make_view(_opponent_hand[i])
		v.face_up = false
		_opp_row.add_child(v)
		_opp_views.append(v)
	_layout_hand()
	_update_hud()


func _make_view(card: Dictionary) -> CardView:
	var v := CardView.new()
	v.custom_minimum_size = CARD_SIZE
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v.set_card(card)
	v.resized.connect(func() -> void: v.pivot_offset = v.size * 0.5)
	v.gui_input.connect(_on_card_input.bind(v))
	return v


func _layout_hand() -> void:
	for i in _hand_views.size():
		var v := _hand_views[i]
		var lift := 1.0 if i != _selected else 1.12
		v.scale = Vector2(lift, lift)
		v.modulate = Color(1, 1, 1) if i == _selected else Color(1, 1, 1, 0.92)


func _on_card_input(event: InputEvent, view: CardView) -> void:
	if _busy or not (event is InputEventMouseButton):
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(_hand_views.find(view))


func _select(index: int) -> void:
	_selected = index
	for i in _hand_views.size():
		_hand_views[i].selected = i == index
	_layout_hand()


func _on_play_pressed() -> void:
	if _busy or _selected < 0:
		_info.text = "Önce bir kart seç."
		return
	_busy = true
	_play_button.disabled = true
	var idx := _selected
	var mine: Dictionary = _player_hand[idx]
	var theirs: Dictionary = _opponent_hand[idx]
	_select(-1)

	var my_view := _hand_views[idx]
	var opp_view := _opp_views[idx]
	opp_view.face_up = true
	opp_view.queue_redraw()
	var table_center := _table.size * 0.5
	_animate_to(my_view, table_center + Vector2(-62, 0))
	_animate_to(opp_view, table_center + Vector2(62, 0))
	my_view.rotation = 0.06
	opp_view.rotation = -0.06
	_info.text = "Rakip düşünüyor..."

	var result := GameRules.compare(mine, theirs)
	await get_tree().create_timer(0.8).timeout

	_hand_views.remove_at(idx)
	_opp_views.remove_at(idx)
	_player_hand.remove_at(idx)
	_opponent_hand.remove_at(idx)
	if result > 0:
		_player_score += 1
		_flash(Palette.ACCENT)
		_info.text = "%s kazandı! +1" % CardData.describe(mine)
	elif result < 0:
		_opponent_score += 1
		_flash(Palette.DANGER)
		_info.text = "Rakip kazandı: %s" % CardData.describe(theirs)
	else:
		_info.text = "Berabere: %s" % CardData.describe(mine)
	my_view.queue_free()
	opp_view.queue_free()
	_update_hud()
	_layout_hand()

	if _player_hand.is_empty():
		_busy = false
		await get_tree().create_timer(0.8).timeout
		_end_game()
		return
	_info.text = "Bir kart seç, sonra Oyna."
	_busy = false
	_play_button.disabled = false


func _animate_to(view: CardView, target: Vector2) -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(view, "global_position", _table.global_position + target, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(view, "scale", Vector2(0.82, 0.82), 0.35)
	t.tween_property(view, "rotation", (0.06 if view == _hand_views[_selected] else -0.06), 0.35)


func _flash(color: Color) -> void:
	_table.modulate = color
	var t := create_tween()
	t.tween_property(_table, "modulate", Color(1, 1, 1), 0.25)


func _end_game() -> void:
	if _player_score > _opponent_score:
		_play_button.text = "Kazandın — Tekrar"
		_info.text = "Maç bitti: %d - %d. Kazandın!" % [_player_score, _opponent_score]
	else:
		_play_button.text = "Kaybettin — Tekrar"
		_info.text = "Maç bitti: %d - %d." % [_player_score, _opponent_score]
	_play_button.disabled = false
	await get_tree().create_timer(1.4).timeout
	_player_score = 0
	_opponent_score = 0
	_start_round()


func _update_hud() -> void:
	_score_label.text = "Sen %d — %d Rakip" % [_player_score, _opponent_score]
	_deck_label.text = "Deste: %d" % _deck.size()
