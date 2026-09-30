class_name Compass
extends Control

const CARDINALS := {
	0.0: "K",
	45.0: "KD",
	90.0: "D",
	135.0: "GD",
	180.0: "G",
	225.0: "GB",
	270.0: "B",
	315.0: "KB",
}

var heading_deg: float = 0.0
var _font: Font = null


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_heading(radians_yaw: float) -> void:
	var deg := fmod(rad_to_deg(-radians_yaw) + 360.0, 360.0)
	if absf(deg - heading_deg) > 0.01:
		heading_deg = deg
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var mid := w * 0.5
	var px_per_deg := w / 120.0

	draw_line(Vector2(0.0, h * 0.75), Vector2(w, h * 0.75), Color(1, 1, 1, 0.18), 1.0)
	draw_line(Vector2(mid, 0.0), Vector2(mid, h * 0.75), Color(0.498039, 0.831373, 0.756863, 0.55), 1.0)

	for deg in range(0, 360, 15):
		var offset := deg - heading_deg
		if absf(offset) > 62.0:
			continue
		var x := mid + offset * px_per_deg
		var alpha := clampf(1.0 - absf(offset) / 68.0, 0.12, 1.0)
		var is_cardinal: bool = CARDINALS.has(deg)
		var is_major: bool = deg % 45 == 0
		var top := h * (0.34 if is_cardinal else 0.46)
		var col := Color(1, 1, 1, alpha)
		if is_cardinal:
			col = Color(0.498039, 0.831373, 0.756863, alpha)
		draw_line(Vector2(x, top), Vector2(x, h * 0.75), col, 2.0 if is_major else 1.0)
		if is_cardinal and _font:
			var label: String = CARDINALS[deg]
			var size_px := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
			draw_string(_font, Vector2(x - size_px.x * 0.5, top - 6.0), label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
