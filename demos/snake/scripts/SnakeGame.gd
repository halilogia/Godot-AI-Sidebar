class_name SnakeGame
extends Node2D
## Pure simulation: no rendering, no input. The view observes it.

signal state_changed(score: int, alive: bool)
signal food_eaten(cell: Vector2i, points: int)
signal died(cause: String)

const COLS := 24
const ROWS := 16

var snake: Array[Vector2i] = []
var dir: Vector2i = Vector2i.RIGHT
var next_dir: Vector2i = Vector2i.RIGHT
var food: Vector2i = Vector2i.ZERO
var score: int = 0
var alive: bool = true
var step_time: float = 0.14
var _acc: float = 0.0

func reset() -> void:
	alive = true
	score = 0
	step_time = 0.14
	_acc = 0.0
	dir = Vector2i.RIGHT
	next_dir = dir
	var mid := Vector2i(COLS / 2, ROWS / 2)
	snake = [mid, mid - dir, mid - dir * 2, mid - dir * 3]
	_spawn_food()
	state_changed.emit(score, alive)

func turn(d: Vector2i) -> void:
	if d == Vector2i.ZERO or d + dir == Vector2i.ZERO:
		return
	next_dir = d

func _spawn_food() -> void:
	var free: Array[Vector2i] = []
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			if not snake.has(c):
				free.append(c)
	if free.is_empty():
		food = Vector2i(-1, -1)
		return
	food = free[randi() % free.size()]

func tick(delta: float) -> void:
	if not alive:
		return
	_acc += delta
	while _acc >= step_time:
		_acc -= step_time
		_step()

func _step() -> void:
	dir = next_dir
	var head: Vector2i = snake[0] + dir
	if head.x < 0 or head.y < 0 or head.x >= COLS or head.y >= ROWS:
		alive = false
		died.emit("wall")
		state_changed.emit(score, alive)
		return
	var growing: bool = head == food
	# The tail tip vacates this cell, so it is legal to move into it — unless
	# the snake grows this step, in which case every segment still counts.
	var limit: int = snake.size() if growing else snake.size() - 1
	if snake.slice(0, limit).has(head):
		alive = false
		died.emit("self")
		state_changed.emit(score, alive)
		return
	snake.insert(0, head)
	if head == food:
		score += 10
		step_time = maxf(0.055, step_time - 0.003)
		food_eaten.emit(food, 10)
		_spawn_food()
	else:
		snake.resize(snake.size() - 1)
	state_changed.emit(score, alive)

func food_eaten_pending() -> bool:
	return snake.size() > 0 and food == snake[0]
