extends Node

signal player_died
signal score_changed(new_score: int)
signal wave_changed(wave: int)
signal health_changed(health: int)

var game_health := 5
var game_score := 0
var wave := 0
var damage_flash := 0.0
var shake := 0.0

func add_score(amount: int) -> void:
	game_score += amount
	score_changed.emit(game_score)

func reset() -> void:
	game_health = 5
	game_score = 0
	wave = 0
	damage_flash = 0.0
	shake = 0.0
