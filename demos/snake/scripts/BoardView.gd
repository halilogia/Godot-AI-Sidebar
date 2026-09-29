extends Control

@onready var game_root: Control = get_parent().get_parent()

func _draw() -> void:
	if game_root and game_root.has_method("draw_board"):
		game_root.draw_board(self)
