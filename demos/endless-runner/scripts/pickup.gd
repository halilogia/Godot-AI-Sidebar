extends Area2D
class_name Pickup

var taken := false
var _t := 0.0
var coin: Polygon2D


signal collected

func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if taken:
		return
	_t += delta * 4.0
	if coin:
		var s := 0.85 + 0.15 * absf(sin(_t))
		coin.scale = Vector2(s, 1.0)
		coin.rotation = sin(_t * 0.5) * 0.25


func _on_body_entered(body: Node2D) -> void:
	if taken or not body.is_in_group("player"):
		return
	taken = true
	monitoring = false
	queue_free()
