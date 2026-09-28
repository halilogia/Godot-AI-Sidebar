extends CharacterBody2D
class_name Player

signal hit

const GRAVITY := 2100.0
const JUMP_VELOCITY := -760.0
const DUCK_GRAVITY_BOOST := 1.35
const FIXED_X := 300.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12

var alive := true
var ducking := false

@onready var sprite: Polygon2D = $Sprite
@onready var shadow: Polygon2D = $Shadow
@onready var hitbox: Area2D = $Hitbox

var _flash := 0.0
var _coyote := 0.0
var _buffer := 0.0
var _base_color := Palette.PRIMARY


func _ready() -> void:
	add_to_group("player")
	_base_color = sprite.color


func _physics_process(delta: float) -> void:
	if not alive:
		velocity.y += GRAVITY * delta
		velocity.x = 0.0
		move_and_slide()
		rotation = lerp(rotation, deg_to_rad(70.0), delta * 6.0)
		return

	ducking = Input.is_action_pressed("duck") and is_on_floor()
	_duck_visual(delta)

	var g := GRAVITY
	if not is_on_floor():
		velocity.y += g * delta

	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(0.0, _buffer - delta)

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0

	if Input.is_action_just_released("jump") and velocity.y < -200.0:
		velocity.y *= 0.55

	velocity.x = 0.0
	position.x = FIXED_X
	move_and_slide()

	_flash = maxf(0.0, _flash - delta)
	sprite.color = _base_color.lerp(Palette.DANGER, clampf(_flash * 8.0, 0.0, 1.0))


func _duck_visual(delta: float) -> void:
	var target := 0.58 if ducking else 1.0
	var sy := lerpf(sprite.scale.y, target, delta * 18.0)
	var sx := lerpf(sprite.scale.x, 1.0 / maxf(sy, 0.4), delta * 18.0)
	sprite.scale = Vector2(sx, sy)
	sprite.position.y = 34.0 - 20.0 * sy
	shadow.scale.x = sx
	shadow.scale.y = 1.0


func set_flash() -> void:
	_flash = 0.12


func kill() -> void:
	if not alive:
		return
	alive = false
	velocity = Vector2(0.0, -420.0)
	hitbox.set_deferred("monitoring", false)
	hit.emit()
