class_name Pickup
extends Node2D

var kind := "heal"
var life := 12.0
var t := 0.0

func _ready() -> void:
	add_to_group("pickup")

func _process(delta: float) -> void:
	t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and global_position.distance_to(players[0].global_position) < 22.0:
		if kind == "heal":
			Global.game_health = mini(5, Global.game_health + 1)
			Global.health_changed.emit(Global.game_health)
		else:
			Global.add_score(25)
		get_tree().call_group("fx", "burst", global_position, Palette.ACCENT, 12)
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(t * 6.0) * 0.08
	draw_circle(Vector2.ZERO, 11.0 * pulse + 2.0, Palette.ACCENT * Color(1, 1, 1, 0.2))
	var col := Palette.ACCENT if kind == "heal" else Palette.PRIMARY
	draw_circle(Vector2.ZERO, 9.0 * pulse, col)
	draw_circle(Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.5))
