class_name Palette
extends RefCounted

## Single source of truth for colours. Never hardcode a colour anywhere else.

const BG_DEEP := Color("#0A0E14")
const BG_MID := Color("#0F1621")
const SURFACE := Color("#141B26")
const SURFACE_LIGHT := Color("#1E2836")
const BORDER := Color("#26344A")

const PRIMARY := Color("#4ADE80")
const PRIMARY_DARK := Color("#15803D")
const ACCENT := Color("#FBBF24")
const DANGER := Color("#F04438")

const TEXT := Color("#E6EDF6")
const TEXT_DIM := Color("#8FA3BC")

## Background vertical gradient.
static func background_gradient(height: float) -> Array[Color]:
	var top := BG_MID
	var bottom := BG_DEEP
	return [top, bottom]

## Green ramp along the snake, index 0 = head.
static func snake_color(t: float) -> Color:
	return PRIMARY.lerp(PRIMARY_DARK, clampf(t, 0.0, 1.0))
