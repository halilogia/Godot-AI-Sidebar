extends Area2D

signal interacted()

@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and prompt_label and prompt_label.visible:
		interacted.emit()
		print("Etkileşim gerçekleşti: ", name)

func _on_body_entered(body: Node2D) -> void:
	if body.name.begins_with("Player") and prompt_label:
		prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name.begins_with("Player") and prompt_label:
		prompt_label.visible = false
