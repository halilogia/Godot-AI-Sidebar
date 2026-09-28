extends Node2D
class_name Coin

var t := 0.0
var base_y := 0.0
var collected := false

func _ready() -> void:
	add_to_group("coins")
	t = randf() * TAU
	base_y = position.y

func _process(delta: float) -> void:
	t += delta * 3.0
	position.y = base_y + sin(t) * 5.0

func _draw() -> void:
	draw_circle(Vector2(0, 2), 12.0, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, 11.0, Palette.ACCENT)
	draw_circle(Vector2.ZERO, 6.0, Color(1, 1, 1, 0.55))
	draw_circle(Vector2.ZERO, 11.0, Palette.ACCENT, false, 2.0)
