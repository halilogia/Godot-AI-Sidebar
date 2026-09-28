class_name Palette
extends RefCounted

## Single source of truth for every colour in the game.
## Keep in sync with res://.agents/rules/art-direction.md

const SKY := Color("#101225")
const MID := Color("#1a1f3d")
const SURFACE := Color("#262c52")
const PRIMARY := Color("#4ce6b3")
const ACCENT := Color("#ffd166")
const DANGER := Color("#ef476f")

const TEXT := Color("#eef2ff")
const OUTLINE := Color("#0a0c1a")

static func darken(c: Color, amount: float = 0.25) -> Color:
	return c.darkened(amount)

static func with_alpha(c: Color, a: float) -> Color:
	var o := c
	o.a = a
	return o
