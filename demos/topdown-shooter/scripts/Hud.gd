extends CanvasLayer

@onready var score: Label = $Panel/Score
@onready var wave: Label = $Panel/Wave
@onready var hp: Label = $Panel/HP

func _ready() -> void:
	Global.score_changed.connect(func(v: int) -> void: score.text = "SCORE %d" % v)
	Global.wave_changed.connect(func(v: int) -> void: wave.text = "WAVE %d" % v)
	Global.health_changed.connect(func(v: int) -> void: hp.text = "HP %d" % v)
	score.text = "SCORE 0"
	wave.text = "WAVE 1"
	hp.text = "HP 5"
