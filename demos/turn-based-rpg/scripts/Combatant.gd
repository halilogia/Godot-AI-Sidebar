class_name Combatant
extends Node2D

signal stats_changed(c: Combatant)
signal died(c: Combatant)

var cname: String = ""
var max_hp: int = 60
var hp: int = 60
var max_mp: int = 20
var mp: int = 20
var attack: int = 12
var defense: int = 4
var is_player: bool = false
var is_shielded: bool = false
var shape: int = 0  # 0 knight, 1 mage, 2 brute, 3 goblin, 4 shaman, 5 hound
var active: bool = false

const CARD := Vector2(196, 168)

func is_alive() -> bool:
	return hp > 0

func receive(amount: int) -> void:
	hp = maxi(0, hp - amount)
	stats_changed.emit(self)
	if hp == 0:
		died.emit(self)

func spend_mp(amount: int) -> bool:
	if mp < amount:
		return false
	mp -= amount
	stats_changed.emit(self)
	return true

func _draw() -> void:
	var r := CARD * 0.5
	draw_rect(Rect2(-r, CARD), Palette.SURFACE_RAISED if is_player else Palette.SURFACE, true)
	draw_rect(Rect2(-r, CARD), Palette.ACCENT if is_player else Palette.DANGER, false, 3.0)
	draw_set_transform(Vector2(0, 30), 0.0, Vector2(0.75, 0.75))
	var col := Palette.ACCENT if is_player else Palette.DANGER
	col.a = 0.9
	match shape:
		0:
			draw_colored_polygon(PackedVector2Array([Vector2(0,-70),Vector2(-30,-40),Vector2(30,-40)]), col)
			draw_circle(Vector2(0,-22), 16, col)
		1:
			draw_colored_polygon(PackedVector2Array([Vector2(0,-80),Vector2(-34,0),Vector2(34,0)]), col)
			draw_circle(Vector2(0,-40), 14, col)
		2:
			draw_rect(Rect2(-38,-60,76,90), col)
			draw_circle(Vector2(0,-70), 18, col)
		3:
			draw_colored_polygon(PackedVector2Array([Vector2(0,-50),Vector2(-24,-10),Vector2(24,-10)]), col)
		4:
			draw_colored_polygon(PackedVector2Array([Vector2(-26,0),Vector2(0,-60),Vector2(26,0)]), col)
		5:
			draw_circle(Vector2(0,-30), 24, col)
			draw_colored_polygon(PackedVector2Array([Vector2(-34,-52),Vector2(-18,-70),Vector2(-24,-44)]), col)
			draw_colored_polygon(PackedVector2Array([Vector2(34,-52),Vector2(18,-70),Vector2(24,-44)]), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var w := CARD.x - 24.0
	var top := -r.y
	draw_string(ThemeDB.fallback_font, Vector2(-w * 0.5, top + 28), cname,
		HORIZONTAL_ALIGNMENT_LEFT, w, 16, Palette.PRIMARY)
	var frac := float(hp) / float(max_hp)
	draw_rect(Rect2(-w * 0.5, top + 36, w, 9), Color(0, 0, 0, 0.7), true)
	var hc := Palette.ACCENT if is_player else Palette.DANGER
	draw_rect(Rect2(-w * 0.5, top + 36, w * frac, 9), hc, true)
	var mw := w * (float(mp) / float(max_mp))
	draw_rect(Rect2(-w * 0.5, top + 48, w, 5), Color(0, 0, 0, 0.6), true)
	draw_rect(Rect2(-w * 0.5, top + 48, mw, 5), Color("#5B7FA6"), true)
	if is_shielded:
		draw_arc(Vector2(0, 30), 40.0, 0, TAU, 32, Palette.ACCENT, 3.0)
	if not is_alive():
		draw_rect(Rect2(-r, CARD), Color(0, 0, 0, 0.65), true)
		draw_string(ThemeDB.fallback_font, Vector2(-w * 0.5, 140), cname,
			HORIZONTAL_ALIGNMENT_LEFT, w, 16, Color(0.6, 0.55, 0.5))
		return
	if active:
		draw_rect(Rect2(-r, CARD), Palette.ACCENT, false, 5.0)
		draw_circle(Vector2(0, 0), 7, Palette.ACCENT)
