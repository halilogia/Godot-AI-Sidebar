class_name Target
extends StaticBody3D

## Vücudun ortasından yukarısı kafa sayılır.
const HEAD_HEIGHT := 1.35

@onready var _mesh: MeshInstance3D = $Flip
var _base_transform: Transform3D
var _flash_time: float = 0.0
var _falling: bool = false
var _base_mat: StandardMaterial3D


func _ready() -> void:
	_base_transform = global_transform
	_base_mat = _mesh.material_override as StandardMaterial3D


func take_hit(_from: Vector3, _is_headshot: bool) -> void:
	if _falling:
		return
	_flash(Palette.ACCENT if not _is_headshot else Palette.DANGER)
	_topple()


func _flash(color: Color) -> void:
	var m := _base_mat.duplicate() as StandardMaterial3D
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.8
	_mesh.material_override = m
	_flash_time = 0.12


func _topple() -> void:
	_falling = true
	_mesh.material_override = _material(Palette.SURFACE.darkened(0.25))
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "rotation_degrees:z", 82.0, 0.35)


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_mesh.material_override = _base_mat


func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m
