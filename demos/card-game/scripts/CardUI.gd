class_name CardUI
extends Control

signal card_clicked(card_ui: CardUI)

var data: CardData

@onready var bg_panel: Panel = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var cost_badge: Label = $Panel/CostBadge
@onready var type_badge: Label = $Panel/Margin/VBox/TypeBadge
@onready var desc_label: Label = $Panel/Margin/VBox/DescLabel
@onready var power_label: Label = $Panel/Margin/VBox/PowerLabel

var is_hovered: bool = false
var original_y: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(130, 190)
	size = Vector2(130, 190)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	if data:
		refresh_ui()

func setup(p_data: CardData) -> void:
	data = p_data
	if is_inside_tree():
		refresh_ui()

func refresh_ui() -> void:
	if not data:
		return
	title_label.text = data.title
	cost_badge.text = str(data.cost)
	desc_label.text = data.description

	match data.type:
		CardData.Type.ATTACK:
			type_badge.text = "[SALDIRI]"
			type_badge.modulate = Color("#ef4444")
			power_label.text = "Hasar: " + str(data.value)
			power_label.modulate = Color("#ef4444")
		CardData.Type.DEFEND:
			type_badge.text = "[SAVUNMA]"
			type_badge.modulate = Color("#3b82f6")
			power_label.text = "Kalkan: " + str(data.value)
			power_label.modulate = Color("#3b82f6")
		CardData.Type.HEAL:
			type_badge.text = "[İYİLEŞME]"
			type_badge.modulate = Color("#10b981")
			power_label.text = "Can: +" + str(data.value)
			power_label.modulate = Color("#10b981")

func _on_mouse_entered() -> void:
	is_hovered = true
	var tw := create_tween()
	tw.tween_property(self, "position:y", original_y - 20.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.15)

func _on_mouse_exited() -> void:
	is_hovered = false
	var tw := create_tween()
	tw.tween_property(self, "position:y", original_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(self)
