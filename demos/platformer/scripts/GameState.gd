extends Node

signal coin_collected(count: int)
signal player_died
signal player_won

var coins: int = 0
var max_coins: int = 0

func reset() -> void:
	coins = 0
	max_coins = 0

func register_coin() -> void:
	max_coins += 1

func collect_coin() -> void:
	coins += 1
	coin_collected.emit(coins)
	if coins >= max_coins and max_coins > 0:
		player_won.emit()

func trigger_player_death() -> void:
	player_died.emit()
