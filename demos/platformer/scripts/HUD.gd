class_name HUD
extends CanvasLayer

@onready var _health: Label = $Top/LblHealth
@onready var _score: Label = $Top/LblScore
@onready var _deaths: Label = $Top/LblDeaths
@onready var _time: Label = $Top/LblTime
@onready var _banner: Label = $Banner
@onready var _hint: Label = $Hint


func _ready() -> void:
	_banner.text = ""
	_hint.text = "A / D veya OKLAR: hareket    SPACE: zıpla    R: yeniden başlat"


func set_health(value: int) -> void:
	_health.text = "CAN: %d / %d" % [maxi(value, 0), Player.MAX_HEALTH]


func set_score(value: int) -> void:
	_score.text = "SKOR: %d" % value


func set_deaths(value: int) -> void:
	_deaths.text = "OLUM: %d" % value


func set_time(seconds: float) -> void:
	_time.text = "SURE: %.1f" % seconds


func show_banner(text: String, seconds: float) -> void:
	_banner.text = text
	_banner.modulate.a = 1.0
	if seconds <= 0.0:
		return
	var tween: Tween = create_tween()
	tween.tween_interval(seconds)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.25)
