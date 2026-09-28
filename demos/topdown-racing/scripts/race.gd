extends Node2D

const LAPS := 3

@onready var player: Car = $Player
@onready var rival: Car = $Rival
@onready var hud: CanvasLayer = $HUD
@onready var lap_label: Label = $HUD/LapLabel
@onready var time_label: Label = $HUD/TimeLabel
@onready var pos_label: Label = $HUD/PosLabel
@onready var msg_label: Label = $HUD/Message
@onready var speed_bar: ProgressBar = $HUD/SpeedBar

var countdown := 3.2
var player_done := false
var rival_done := false
var player_time := 0.0
var rival_time := 0.0

func _ready() -> void:
	player.body_color = Color(0.95, 0.26, 0.2)
	player.car_name = "SEN"
	player.max_laps = LAPS
	player.running = false
	player.lap_time = 0.0
	player.total_time = 0.0
	rival.body_color = Color(0.25, 0.55, 1.0)
	rival.car_name = "RAKIP"
	rival.is_ai = true
	rival.max_laps = LAPS
	rival.running = false
	rival.global_position = player.global_position + Vector2(0, 90)
	rival._prev_progress = player._prev_progress
	rival.lap = 0
	rival.lap_time = 0.0
	rival.total_time = 0.0
	rival._target_idx = 0
	player.refresh_visual()
	rival.refresh_visual()
	player.race_finished.connect(_on_player_finished)
	rival.race_finished.connect(_on_rival_finished)
	msg_label.modulate = Color(1, 1, 1, 0)

func _process(delta: float) -> void:
	if countdown > 0.0:
		countdown -= delta
		var n := ceili(countdown)
		if n > 0:
			msg_label.text = str(n)
			msg_label.modulate = Color(1, 1, 1, 1)
		else:
			msg_label.text = "BAŞLA!"
			msg_label.modulate = Color(0.4, 1, 0.5, 1)
			player.running = true
			rival.running = true
	elif msg_label.text == "BAŞLA!":
		msg_label.modulate.a = maxf(0.0, msg_label.modulate.a - delta * 1.5)

	lap_label.text = "TUR %d / %d" % [mini(player.lap + 1, LAPS), LAPS]
	time_label.text = "SÜRE  " + fmt_time(player.total_time)
	if player.has_finished:
		pos_label.text = "BİTTİ  " + fmt_time(player_time)
	else:
		pos_label.text = "SIRA  %s" % ("1" if (not player_done and not rival_done) or (player_done and not rival_done) or (rival_done and player_time < rival_time) else "2")
	speed_bar.value = clampf(player.speed / Car.MAX_SPEED * 100.0, 0.0, 100.0)

func _on_player_finished(t: float) -> void:
	if player_done:
		return
	player_done = true
	player_time = t
	_show_result()

func _on_rival_finished(t: float) -> void:
	if rival_done:
		return
	rival_done = true
	rival_time = t
	_show_result()

func _show_result() -> void:
	if not player_done:
		if msg_label.text == "BAŞLA!":
			msg_label.text = ""
		_show("KAYBETTİN!  " + fmt_time(rival_time))
		return
	if not rival_done:
		_show("KAZANDIN!  " + fmt_time(player_time))
		return
	if player_time <= rival_time:
		_show("KAZANDIN!  " + fmt_time(player_time))
	else:
		_show("KAYBETTİN!  " + fmt_time(player_time))

func _show(t: String) -> void:
	msg_label.text = t
	msg_label.modulate = Color(1, 0.95, 0.6, 1)

func fmt_time(t: float) -> String:
	var m := int(t) / 60
	var s := t - float(m * 60)
	return "%d:%05.2f" % [m, s]
