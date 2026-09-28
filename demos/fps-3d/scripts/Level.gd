extends Node3D

@onready var hud: Control = $Hud


func _ready() -> void:
	GameState.reset()
	GameState.register_total()
	GameState.changed.connect(hud._on_changed)
	GameState.changed.emit(GameState.collected, GameState.total)
