class_name CardGame
extends Control

## 1280x720 tablo kart savaşı: oyuncu elindeki 5 karttan birini seçer,
## rakip rastgele atar, yüksek değer eli kazanır.

const HAND_SIZE := 5
const HUD_H := 96
const FIELD_TOP := 120
const HAND_Y := 470

var deck: Array[Dictionary] = []
var hand: Array[Dictionary] = []
var views: Array[CardView] = []
var played: Array[CardView] = []
var busy := false
var round_won := 0  # 0 = devam, 1 = oyuncu, 2 = rakip
var score_player := 0
var score_opponent := 0

var status_label: Label
var score_label: Label
var turn_label: Label
var play_button: Button
var result_panel: PanelContainer
var result_label: Label
var bg: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_hud()
	_build_field()
	new_game()


# ---------- kurulum ----------

func _build_background() -> void:
	bg = ColorRect.new()
	bg.color = Palette.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var grad := Gradient.new()
	grad.set_color(0, Palette.BG_LIGHT)
	grad.set_color(1, Palette.BG_DEEP)
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.2, 0.0)
	gtex.fill_to = Vector2(0.8, 1.0)
	gtex.width = 128
	gtex.height = 128
	var layer := TextureRect.new()
	layer.texture = gtex
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)


func _build_hud() -> void:
	var hud := PanelContainer.new()
	hud.add_theme_stylebox_override("panel", UiFactory.panel_style(Palette.SURFACE_DARK, 0, 0))
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.custom_minimum_size = Vector2(0, HUD_H)
	hud.offset_left = 16
	hud.offset_right = -16
	hud.offset_top = 16
	hud.add_child(_hud_row())
	add_child(hud)


func _hud_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	var title := UiFactory.label("SAVAŞ MASASI", 32, Palette.PRIMARY)
	row.add_child(title)

	score_label = UiFactory.label("Sen 0 — Rakip 0", 22)
	row.add_child(score_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	play_button = UiFactory.button("  YENİ OYUN  ")
	play_button.pressed.connect(new_game)
	row.add_child(play_button)
	return row


func _build_field() -> void:
	var table := PanelContainer.new()
	table.add_theme_stylebox_override("panel", UiFactory.panel_style(Palette.SURFACE.darkened(0.35), 16, 2, Palette.SURFACE.lightened(0.15)))
	table.set_anchors_preset(Control.PRESET_TOP_WIDE)
	table.offset_left = 96
	table.offset_right = -96
	table.offset_top = FIELD_TOP
	table.offset_bottom = 384
	add_child(table)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	table.add_child(col)

	turn_label = UiFactory.label("Kartını seç", 22, Palette.ACCENT)
	col.add_child(turn_label)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 60)
	col.add_child(mid)

	status_label = UiFactory.label("  —  ", 28, Palette.TEXT)
	status_label.custom_minimum_size = Vector2(200, 0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(status_label)

	result_panel = PanelContainer.new()
	result_panel.add_theme_stylebox_override("panel", UiFactory.panel_style(Palette.SURFACE, 10, 2, Palette.PRIMARY))
	result_panel.visible = false
	result_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result_label = UiFactory.label("", 28)
	result_panel.add_child(result_label)
	col.add_child(result_panel)


# ---------- oyun ----------

func new_game() -> void:
	deck = CardData.build_deck()
	deck.shuffle()
	hand.clear()
	score_player = 0
	score_opponent = 0
	round_won = 0
	busy = false
	for i in HAND_SIZE:
		hand.append(deck.pop_back())
	result_panel.visible = false
	_refresh_hud()
	_rebuild_hand()


var _hand_ids: Array[int] = []

func _rebuild_hand() -> void:
	for v in views:
		v.queue_free()
	views.clear()
	var n := hand.size()
	if n == 0:
		round_won = 1 if score_player > score_opponent else (2 if score_opponent > score_player else 0)
		result_label.text = "OYUN BİTTİ — %d / %d" % [score_player, score_opponent]
		result_label.add_theme_color_override("font_color", Palette.PRIMARY if round_won == 1 else Palette.DANGER)
		result_panel.visible = true
		turn_label.text = "YENİ OYUN butonuna bas"
		return
	var spacing := 24.0
	var total := float(n) * CardView.W + float(max(0, n - 1)) * spacing
	var start_x := (size.x - total) * 0.5
	for i in n:
		var v := CardView.new()
		v.set_card(hand[i])
		v.interactive = true
		v.card_pressed.connect(_on_card_pressed)
		add_child(v)
		var x := start_x + float(i) * (CardView.W + spacing)
		v.position = Vector2(x, HAND_Y)
		v.set_base_y(HAND_Y)
		views.append(v)


func _refresh_hud() -> void:
	score_label.text = "Sen %d  —  Rakip %d" % [score_player, score_opponent]
	if round_won == 0:
		turn_label.text = "Kartını seç"


func _on_card_pressed(view: CardView) -> void:
	if busy or round_won != 0:
		return
	var index := views.find(view)
	if index < 0:
		return
	busy = true
	turn_label.text = "Rakip düşünüyor…"
	var card: Dictionary = hand[index]
	var enemy: Dictionary = deck.pop_back()
	deck.append(enemy)
	await get_tree().create_timer(0.45).timeout
	_show_result(card, enemy)
	await get_tree().create_timer(0.9).timeout
	busy = false
	hand.remove_at(index)
	_rebuild_hand()


func _show_result(my_card: Dictionary, enemy: Dictionary) -> void:
	if my_card["rank"] > enemy["rank"]:
		score_player += 1
		result_label.text = "KAZANDIN!   %s  >  %s" % [CardData.label(my_card), CardData.label(enemy)]
		result_label.add_theme_color_override("font_color", Palette.PRIMARY)
	elif my_card["rank"] < enemy["rank"]:
		score_opponent += 1
		result_label.text = "KAYBETTİN!   %s  <  %s" % [CardData.label(my_card), CardData.label(enemy)]
		result_label.add_theme_color_override("font_color", Palette.DANGER)
	else:
		result_label.text = "BERABERE   %s  =  %s" % [CardData.label(my_card), CardData.label(enemy)]
		result_label.add_theme_color_override("font_color", Palette.ACCENT)
	result_panel.visible = true
	_refresh_hud()
	_show_played(my_card, true)
	_show_played(enemy, false)


## Oynanan kartı alanda gösterir. mine=false ise rakip kartı (sağ).
func _show_played(c: Dictionary, mine: bool) -> void:
	for v in views:
		v.set_dimmed(true)
	for v in played:
		v.queue_free()
	played.clear()
	var v := CardView.new()
	v.set_card(c)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var cx := 320.0 if mine else 960.0
	v.position = Vector2(cx, 190.0)
	v.set_base_y(190.0)
