extends AnimatableBody2D
class_name MovingPlatform

var from_pos := Vector2.ZERO
var to_pos := Vector2.ZERO
var t := 0.0
var speed := 0.35

func _ready() -> void:
	sync_to_physics = true

func setup(a: Vector2, b: Vector2) -> void:
	from_pos = a
	to_pos = b
	position = a
	t = randf()

func _physics_process(delta: float) -> void:
	t = fposmod(t + delta * speed, 2.0)
	var k := 0.5 - 0.5 * cos(t * PI)
	position = from_pos.lerp(to_pos, k)
	# sync_to_physics lets CharacterBody2D riders be carried by the platform.

func _draw() -> void:
	draw_rect(Rect2(-48, -12, 96, 20), Color(Palette.PRIMARY.r, Palette.PRIMARY.g, Palette.PRIMARY.b, 0.25), true)
	draw_rect(Rect2(-48, -12, 96, 20), Palette.PRIMARY, true)
	draw_rect(Rect2(-40, -8, 80, 4), Palette.BG_DEEP, true)
