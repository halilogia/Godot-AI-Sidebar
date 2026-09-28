class_name CardView
extends Control

var card: Dictionary = {}
var face_up := true
var selected := false:
	set(v):
		selected = v
		queue_redraw()

func _ready() -> void:
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_card(c: Dictionary) -> void:
	card = c
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if card.is_empty():
		return
	draw_rect(Rect2(Vector2(4, 6), size), Color(0, 0, 0, 0.22), true)
	if not face_up:
		draw_rect(r, Palette.SURFACE, true)
		draw_rect(r.grow(-6.0), Palette.PRIMARY.darkened(0.35), true)
		draw_rect(r.grow(-6.0), Palette.PRIMARY, false, 2.0)
		draw_rect(r, Color(0, 0, 0, 0.45), false, 2.0)
		return
	draw_rect(r, Palette.CARD, true)
	draw_rect(r.grow(-3.0), Palette.CARD.darkened(0.12), false, 1.0)
	var ink := Palette.DANGER if card["red"] else Palette.TEXT_DARK
	if selected:
		draw_rect(r.grow(4.0), Palette.PRIMARY, false, 4.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(10, 34), card["rank"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ink)
	draw_string(font, Vector2(8, size.y - 12), CardData.suit_symbol(card["suit"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ink)
	draw_string(font, Vector2(size.x * 0.5 - 40.0, size.y * 0.5 + 14.0), CardData.suit_symbol(card["suit"]), HORIZONTAL_ALIGNMENT_CENTER, 80, 46, ink)
	draw_string(font, Vector2(10, size.y - 34), CardData.suit_name(card["suit"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.TEXT_DARK.lightened(0.15))
