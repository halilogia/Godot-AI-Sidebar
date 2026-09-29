extends Control

@onready var score_label: Label = %ScoreLabel
@onready var best_label: Label = %BestLabel
@onready var message_label: Label = %MessageLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.visible = false

func _process(_delta: float) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		position = Vector2.ZERO
		size = vp
	queue_redraw()

func _draw() -> void:
	var bar := Rect2(24, 14, size.x - 48, 62)
	draw_rect(bar.grow(4), Color(0, 0, 0, 0.35), true)
	draw_rect(bar, Color(Palette.SURFACE, 0.9), true)
	draw_rect(bar, Color(Palette.PRIMARY, 0.25), false, 2.0)

func set_score(value: int) -> void:
	score_label.text = "SCORE  %d" % value

func set_best(value: int) -> void:
	best_label.text = "BEST  %d" % value

func show_message(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	message_label.visible = true

func hide_message() -> void:
	message_label.visible = false
