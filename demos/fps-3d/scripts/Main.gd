extends Node3D

@onready var score_label: Label = $HUD/Panel/Margin/VBox/Score
@onready var hint: Label = $HUD/Hint

var score := 0
var total := 0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var coins := $Level/Coins
	total = coins.get_child_count()
	for c in coins.get_children():
		c.collected.connect(_on_collected)
	_update()

func _on_collected(value: int) -> void:
	score += value
	_update()

func _update() -> void:
	score_label.text = "TOPLANDI  %d / %d" % [score, total]
	if score >= total:
		hint.text = "TAMAMLANDI - R ile yeniden basla"
		hint.add_theme_color_override("font_color", Color("#ffd166"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
