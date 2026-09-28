extends Area2D
class_name Obstacle

@export var kind := "spike"  # "spike" (ground) or "drone" (air, must duck)
var _t := 0.0
var body_shape: CollisionShape2D
var body_vis: Polygon2D
var hit_shape: CollisionShape2D
var _base_color := Palette.DANGER


func _ready() -> void:
	add_to_group("obstacles")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	if body_vis:
		if kind == "drone":
			body_vis.position.y = sin(_t * 3.0) * 8.0
			body_vis.rotation = sin(_t * 2.0) * 0.08
		else:
			body_vis.scale = Vector2(1.0, 1.0 - 0.06 * absf(sin(_t * 5.0)))


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("kill"):
		body.kill()
