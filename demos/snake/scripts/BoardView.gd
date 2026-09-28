class_name BoardView
extends Node2D
## Draws the board, snake and food procedurally.

const CELL := 32

@export var game: SnakeGame

var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	var board := Rect2(0, 0, SnakeGame.COLS * CELL, SnakeGame.ROWS * CELL)
	draw_rect(board, Palette.SURFACE, true)
	# Subtle grid so the field is not one flat colour.
	for x in range(1, SnakeGame.COLS):
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, board.size.y),
				Palette.SURFACE_LIGHT, 1.0)
	for y in range(1, SnakeGame.ROWS):
		draw_line(Vector2(0, y * CELL), Vector2(board.size.x, y * CELL),
				Palette.SURFACE_LIGHT, 1.0)
	draw_rect(board, Palette.BORDER, false, 2.0)

	_draw_food()
	_draw_snake()

func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(c.x * CELL + 2, c.y * CELL + 2, CELL - 4, CELL - 4)

func _draw_food() -> void:
	if game.food.x < 0:
		return
	var r := _cell_rect(game.food)
	var pulse := 1.0 + sin(_t * 6.0) * 0.12
	var c := r.get_center()
	draw_circle(c, 9.0 * pulse, Color(Palette.ACCENT, 0.25))
	draw_circle(c, 6.0 * pulse, Palette.ACCENT)

func _draw_snake() -> void:
	var n: int = game.snake.size()
	for i in range(n - 1, -1, -1):
		var r := _cell_rect(game.snake[i])
		var t := 0.0 if n == 1 else float(i) / float(n - 1)
		var col := Palette.snake_color(t)
		if i == 0:
			# Head: brighter with two eyes looking in the travel direction.
			draw_rect(r.grow(2.0), col, true)
			var d := Vector2(game.dir)
			var eye := Vector2(5, 0).rotated(d.angle()) if d.length() > 0.5 else Vector2.ZERO
			var c := r.get_center()
			draw_circle(c + eye + Vector2(0, -6), 2.6, Palette.BG_DEEP)
			draw_circle(c + eye + Vector2(0, 6), 2.6, Palette.BG_DEEP)
		else:
			draw_rect(r, col, true)
			draw_rect(r, col.darkened(0.35), false, 1.0)
