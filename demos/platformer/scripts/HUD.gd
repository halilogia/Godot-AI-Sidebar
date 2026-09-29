extends CanvasLayer

@onready var coin_label: Label = $HUDPanel/CoinLabel
@onready var victory_panel: PanelContainer = $VictoryPanel

func _ready() -> void:
	victory_panel.visible = false
	GameState.coin_collected.connect(_on_coin_collected)
	GameState.player_won.connect(_on_player_won)
	_update_text(0)

func _on_coin_collected(count: int) -> void:
	_update_text(count)

func _update_text(count: int) -> void:
	coin_label.text = "COINS: %d / %d" % [count, GameState.max_coins]

func _on_player_won() -> void:
	victory_panel.visible = true
	var tw := create_tween()
	victory_panel.scale = Vector2(0.8, 0.8)
	tw.tween_property(victory_panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
