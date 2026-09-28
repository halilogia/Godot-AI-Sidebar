class_name Background
extends Node2D
## Procedural dusk gradient + vignette + soft glow behind the board.
## Code-drawn instead of a shader so it cannot fail to compile at runtime.

const W := 1280.0
const H := 720.0
const STEPS := 48

func _draw() -> void:
	# Vertical gradient, top slightly lighter (dusk sky) to deep bottom.
	for i in STEPS:
		var t := float(i) / float(STEPS - 1)
		var y := H * float(i) / float(STEPS)
		draw_rect(Rect2(0, y, W, H / float(STEPS) + 1.0),
				Palette.BG_MID.lerp(Palette.BG_DEEP, t), true)

	# Faint glow behind the play field so the board sits in the scene.
	var board_center := Vector2(640.0, 140.0 + SnakeGame.ROWS * BoardView.CELL * 0.5)
	for i in range(8, 0, -1):
		draw_circle(board_center, 220.0 + float(i) * 34.0,
				Color(Palette.PRIMARY_DARK, 0.006))
