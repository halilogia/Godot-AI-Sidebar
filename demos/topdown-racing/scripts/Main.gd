extends Node2D
class_name Main

const COLORS := [Palette.PRIMARY, Palette.ACCENT, Palette.DANGER, Color('#9d7bff')]

@onready var cam: Camera2D = $Camera2D
@onready var hud: RaceHUD = $HUD

var shake := 0.0

func _ready() -> void:
	var race: Race = $Race
	race.cars.clear()
	for i in 4:
		var car: Car = Car.new()
		car.is_player = i == 0
		car.color = COLORS[i]
		car.global_transform = Transform2D(0, Vector2.ZERO) * Track.start_transform(i)
		car.global_position = Track.start_transform(i).origin
		race.add_child(car)
		race.cars.append(car)
	hud.race = race
	cam.make_current()
	RenderingServer.set_default_clear_color(Palette.BG)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_R:
		get_tree().reload_current_scene()

func _process(delta: float) -> void:
	var player: Car = $Race.cars[0]
	var look := Vector2.RIGHT.rotated(player.rotation) * 60.0
	var target := player.global_position + look
	cam.global_position = cam.global_position.lerp(target, clamp(6.0 * delta, 0.0, 1.0))
	shake = maxf(0.0, shake - 6.0 * delta)
	if shake > 0.0:
		cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		cam.offset = Vector2.ZERO
	if not player.is_on_road() and player.speed > 300.0 and player.is_player:
		shake = maxf(shake, 2.0)
