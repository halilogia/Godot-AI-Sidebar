class_name Palette
extends RefCounted

const BG := Color("#14100F")
const SURFACE := Color("#2A2220")
const SURFACE_RAISED := Color("#3A302C")
const PRIMARY := Color("#E8D5B0")
const ACCENT := Color("#F0A830")
const DANGER := Color("#C4453C")

static func panel_style(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb
