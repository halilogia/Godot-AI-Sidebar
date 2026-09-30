class_name HUD
extends Control

@onready var _sway: Control = $Sway
@onready var _compass: Compass = $Sway/Compass
@onready var _heading: Label = $Sway/Compass/Heading
@onready var _hp_fill: ColorRect = $Sway/Vitals/HealthFill
@onready var _hp_label: Label = $Sway/Vitals/HealthLabel
@onready var _st_fill: ColorRect = $Sway/Vitals/StaminaFill
@onready var _ammo_value: Label = $Sway/Ammo/Value
@onready var _ammo_reserve: Label = $Sway/Ammo/Reserve
@onready var _weapon_name: Label = $Sway/Ammo/WeaponName
@onready var _reload_bar: ProgressBar = $Sway/Ammo/ReloadBar
@onready var _mode: Label = $Sway/Ammo/ModeLabel
@onready var _hint: Label = $Hint
@onready var _hitmarker: Control = $Sway/Crosshair/HitMarker

const BAR_W := 300.0
const ST_W := 300.0
const HIT_TIME := 0.18

var _bob_offset: float = 0.0
var _sway_offset: Vector2 = Vector2.ZERO
var _sway_target: Vector2 = Vector2.ZERO
var _hit_time: float = 0.0


func _ready() -> void:
	_hitmarker.visible = false
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)
	on_health(100.0, 100.0)
	on_stamina(100.0, 100.0)


## Arayüzü her zaman ekranın tamamına yay: anchor'lar sahnede override
## edilse bile tüm öğeler doğru köşelere yapışsın.
func _fit_viewport() -> void:
	var vp := get_viewport_rect().size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	size = vp
	_sway.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sway.offset_left = 0.0
	_sway.offset_top = 0.0
	_sway.offset_right = 0.0
	_sway.offset_bottom = 0.0
	_sway.size = vp

	# Alt öğelerin anchor'ları CanvasLayer altında her yeniden yerleşimde
	# düşebiliyor; köşelere preset ile yeniden sabitle.
	_compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_compass.position = Vector2(vp.x * 0.5 - 300.0, 16.0)
	_compass.size = Vector2(600.0, 42.0)
	var vitals := _sway.get_node("Vitals") as Control
	vitals.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.position = Vector2(48.0, vp.y - 118.0)
	vitals.size = Vector2(360.0, 84.0)
	_place_rect(vitals.get_node("HealthBar"), Vector2(0, 0), Vector2(300, 14))
	_place_rect(vitals.get_node("HealthFill"), Vector2(0, 0), Vector2(300, 14))
	_place_rect(vitals.get_node("HealthLabel"), Vector2(0, 18), Vector2(300, 26))
	_place_rect(vitals.get_node("StaminaBar"), Vector2(0, 48), Vector2(300, 10))
	_place_rect(vitals.get_node("StaminaFill"), Vector2(0, 48), Vector2(300, 10))
	_place_rect(vitals.get_node("StaminaLabel"), Vector2(0, 62), Vector2(300, 20))
	var ammo := _sway.get_node("Ammo") as Control
	ammo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo.position = Vector2(vp.x - 240.0, vp.y - 196.0)
	ammo.size = Vector2(192.0, 160.0)

	# Pusula çizgileri ve mermi yazısı ölçüye göre sabit kalsın.
	var crosshair := _sway.get_node("Crosshair") as Control
	crosshair.position = Vector2(vp.x * 0.5 - 18.0, vp.y * 0.5 - 18.0)
	crosshair.size = Vector2(36.0, 36.0)
	_ammo_value.add_theme_font_size_override("font_size", 52)
	_ammo_reserve.add_theme_font_size_override("font_size", 24)
	_place_rect(_ammo_value, Vector2(0, 0), Vector2(192, 62))
	_place_rect(_ammo_reserve, Vector2(0, 66), Vector2(192, 26))
	_place_rect(_weapon_name, Vector2(0, 96), Vector2(192, 24))
	_place_rect(_reload_bar, Vector2(0, 120), Vector2(192, 10))
	_place_rect(_mode, Vector2(0, 132), Vector2(192, 24))
	var hint := _hint as Control
	hint.position = Vector2(48.0, vp.y - 42.0)
	hint.size = Vector2(vp.x - 96.0, 30.0)

func _place_rect(c: Control, pos: Vector2, s: Vector2) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = pos
	c.size = s


func on_health(current: float, maximum: float) -> void:
	var t: float = 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	_hp_fill.size.x = BAR_W * t
	_hp_label.text = "%d" % int(round(current))
	var low := t <= 0.3
	var c: Color = Palette.DANGER if low else Palette.PRIMARY
	_hp_fill.color = Color(c.r, c.g, c.b, 0.9)


func on_stamina(current: float, maximum: float) -> void:
	var t: float = 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	_st_fill.size.x = ST_W * t
	var c2: Color = Palette.ACCENT if t < 0.25 else Palette.PRIMARY
	_st_fill.color = Color(c2.r, c2.g, c2.b, 0.8)


func on_ammo(clip: int, reserve: int) -> void:
	_ammo_value.text = "%d" % clip
	_ammo_reserve.text = "/ %d" % reserve
	_ammo_value.modulate = Palette.DANGER if clip == 0 else Color.WHITE


func on_hit() -> void:
	_hit_time = HIT_TIME
	_hitmarker.visible = true


func set_weapon(name_text: String) -> void:
	_weapon_name.text = name_text


func set_hint(text: String) -> void:
	_hint.text = text


## Reload ilerlemesi 0..1; bitince gizlenir. Eğilme göstergesi mod etiketiyle.
func set_reload_progress(t: float) -> void:
	_reload_bar.visible = t > 0.0
	_reload_bar.value = clampf(t, 0.0, 1.0)


func set_crouch(on: bool) -> void:
	_mode.text = "EĞİLİ" if on else ""


func sway(delta: Vector2) -> void:
	_sway_target = delta


func set_bob(phase: float, amount: float) -> void:
	_bob_offset = amount * sin(phase * 2.0)


func set_yaw(radians_yaw: float) -> void:
	_compass.set_heading(radians_yaw)
	_heading.text = "%03d" % int(round(_compass.heading_deg))


func _process(delta: float) -> void:
	# CanvasLayer hazır olduğunda boyut sonradan eziliyor; her karede
	# viewport ile eşleşmiyorsa yeniden yay.
	var vp := get_viewport_rect().size
	if size != vp or _sway.size != vp:
		_fit_viewport()
	_sway_offset = _sway_offset.lerp(_sway_target, clampf(delta * 9.0, 0.0, 1.0))
	_sway_target = _sway_target.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	_sway.position = Vector2(_sway_offset.x * 14.0, _sway_offset.y * 11.0 + _bob_offset)
	_hitmarker.modulate.a = clampf(_hit_time / HIT_TIME, 0.0, 1.0)
	if _hit_time > 0.0:
		_hit_time -= delta
		if _hit_time <= 0.0:
			_hitmarker.visible = false
