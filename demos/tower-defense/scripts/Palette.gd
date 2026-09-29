class_name Palette
extends RefCounted

const BG_DEEP := Color("#0e1220")
const BG_MID := Color("#1a2033")
const SURFACE := Color("#1b2334")
const SURFACE_LIGHT := Color("#27324a")
const PATH := Color("#3a3428")
const PATH_EDGE := Color("#241f18")
const PRIMARY := Color("#4ea8de")
const ACCENT := Color("#f2a33c")
const DANGER := Color("#e2564a")
const TEXT := Color("#e8eef7")
const TEXT_DIM := Color("#93a3bd")
const FROST := Color("#7fe3e0")
const BORDER := Color(0.23, 0.28, 0.38)
const SHADOW := Color(0, 0, 0, 0.35)

static func shadow_alpha(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 0.0)
