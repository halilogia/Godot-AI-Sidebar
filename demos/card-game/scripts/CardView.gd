class_name CardView
extends Control

## 120x168 kart görünümü: yumuşak gölge, yüz, koz, değer, isim.
## Tüm çizim kod içinde (StyleBoxFlat), doku dosyası yok.

signal card_pressed(view: CardView)

const W := 120.0
const H := 168.0
const RADIUS := 12.0

var card: Dictionary = {}
var interactive := false
var dimmed := false
var _hover := false
var _base_y := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	pivot_offset = Vector2(W * 0.5, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: _set_hover(true))
	mouse_exited.connect(func() -> void: _set_hover(false))


func set_card(c: Dictionary) -> void:
	card = c
	queue_redraw()


func set_dimmed(v: bool) -> void:
	dimmed = v
	queue_redraw()


func set_base_y(y: float) -> void:
	_base_y = y
	position.y = y


func _set_hover(v: bool) -> void:
	_hover = v
	var target := _base_y - 8.0 if v else _base_y
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", target, 0.12)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and interactive:
		accept_event()
		card_pressed.emit(self)


func _draw() -> void:
	if card.is_empty():
		return
	var face := Rect2(Vector2.ZERO, size)
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.35)
	shadow.set_corner_radius_all(int(RADIUS))
	draw_style_box(shadow, Rect2(Vector2(3, 5), size))

	var body := StyleBoxFlat.new()
	body.bg_color = Palette.SURFACE.darkened(0.25) if dimmed else Palette.SURFACE
	body.set_corner_radius_all(int(RADIUS))
	body.set_border_width_all(2)
	body.border_color = Palette.SURFACE.lightened(0.2) if dimmed else Palette.PRIMARY
	draw_style_box(body, face)

	var col: Color = card.get("color", Palette.TEXT)
	if dimmed:
		col = col.darkened(0.35)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(16, 52), str(card["rank"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, col)
	var glyph: String = card["glyph"]
	var gw := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 64)
	draw_string(font, Vector2((size.x - gw.x) * 0.5, size.y * 0.5 + 28.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, col)
	draw_string(font, Vector2(16, size.y - 14), str(card["suit"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
