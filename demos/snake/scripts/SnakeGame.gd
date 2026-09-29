extends Control

# Renk paleti
const COLOR_BG: Color = Color("0f141c")
const COLOR_BOARD_BG: Color = Color("182232")
const COLOR_BOARD_GRID: Color = Color("1e2c40")
const COLOR_BOARD_BORDER: Color = Color("2c3e50")
const COLOR_SNAKE_HEAD: Color = Color("58d68d")
const COLOR_SNAKE_BODY: Color = Color("2ecc71")
const COLOR_SNAKE_OUTLINE: Color = Color("27ae60")
const COLOR_FOOD: Color = Color("e74c3c")
const COLOR_FOOD_GLOW: Color = Color("ff7675")

# Izgara tanımı
const GRID_WIDTH: int = 20
const GRID_HEIGHT: int = 20
const CELL_SIZE: float = 28.0

# Oynanış durumları
var snake: Array[Vector2i] = []
var direction: Vector2i = Vector2i.RIGHT
var next_direction: Vector2i = Vector2i.RIGHT
var food_pos: Vector2i = Vector2i(15, 10)
var score: int = 0
var high_score: int = 0
var game_over: bool = false
var is_paused: bool = false

# Zamanlama
var step_interval: float = 0.12
var move_timer: float = 0.0
var food_pulse_time: float = 0.0

# Görsel referanslar
@onready var score_label: Label = $TopBar/ScoreLabel
@onready var high_score_label: Label = $TopBar/HighScoreLabel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/VBox/FinalScoreLabel
@onready var board_node: Control = $BoardArea/Board

func _ready() -> void:
	start_new_game()

func start_new_game() -> void:
	snake.clear()
	var center_y: int = GRID_HEIGHT / 2
	snake.append(Vector2i(6, center_y))
	snake.append(Vector2i(5, center_y))
	snake.append(Vector2i(4, center_y))
	direction = Vector2i.RIGHT
	next_direction = Vector2i.RIGHT
	score = 0
	game_over = false
	move_timer = 0.0
	update_ui()
	spawn_food()
	game_over_panel.visible = false
	board_node.queue_redraw()

func _input(event: InputEvent) -> void:
	if game_over:
		if event.is_action_pressed("restart_game") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
			start_new_game()
		return

	if event.is_action_pressed("move_up") and direction != Vector2i.DOWN:
		next_direction = Vector2i.UP
	elif event.is_action_pressed("move_down") and direction != Vector2i.UP:
		next_direction = Vector2i.DOWN
	elif event.is_action_pressed("move_left") and direction != Vector2i.RIGHT:
		next_direction = Vector2i.LEFT
	elif event.is_action_pressed("move_right") and direction != Vector2i.LEFT:
		next_direction = Vector2i.RIGHT

func _process(delta: float) -> void:
	food_pulse_time += delta * 4.0
	board_node.queue_redraw()

	if game_over:
		return

	move_timer += delta
	if move_timer >= step_interval:
		move_timer -= step_interval
		step_snake()

func step_snake() -> void:
	direction = next_direction
	var head: Vector2i = snake[0]
	var new_head: Vector2i = head + direction

	# Duvara çarpma kontrolü
	if new_head.x < 0 or new_head.x >= GRID_WIDTH or new_head.y < 0 or new_head.y >= GRID_HEIGHT:
		trigger_game_over()
		return

	# Gövdeye çarpma kontrolü
	for i in range(snake.size() - 1):
		if new_head == snake[i]:
			trigger_game_over()
			return

	snake.insert(0, new_head)

	# Yem yeme kontrolü
	if new_head == food_pos:
		score += 10
		if score > high_score:
			high_score = score
		update_ui()
		spawn_food()
		# Hafif hızlanma
		step_interval = max(0.06, 0.12 - (float(score) / 1000.0) * 0.05)
	else:
		snake.pop_back()

func spawn_food() -> void:
	var available_cells: Array[Vector2i] = []
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell := Vector2i(x, y)
			if not cell in snake:
				available_cells.append(cell)

	if available_cells.size() > 0:
		var idx := randi() % available_cells.size()
		food_pos = available_cells[idx]

func trigger_game_over() -> void:
	game_over = true
	final_score_label.text = "SKOR: " + str(score)
	game_over_panel.visible = true

func update_ui() -> void:
	score_label.text = "SKOR: %04d" % score
	high_score_label.text = "EN YÜKSEK: %04d" % high_score

func draw_board(target: Control) -> void:
	var board_size := Vector2(GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE)

	# Arka plan ve border
	target.draw_rect(Rect2(Vector2.ZERO, board_size), COLOR_BOARD_BG, true)
	target.draw_rect(Rect2(Vector2.ZERO, board_size), COLOR_BOARD_BORDER, false, 2.0)

	# Izgara çizgileri
	for x in range(1, GRID_WIDTH):
		var px := x * CELL_SIZE
		target.draw_line(Vector2(px, 0), Vector2(px, board_size.y), COLOR_BOARD_GRID, 1.0)
	for y in range(1, GRID_HEIGHT):
		var py := y * CELL_SIZE
		target.draw_line(Vector2(0, py), Vector2(board_size.x, py), COLOR_BOARD_GRID, 1.0)

	# Yem çizimi (parlama ve yuvarlak)
	var food_center := Vector2(food_pos.x * CELL_SIZE + CELL_SIZE * 0.5, food_pos.y * CELL_SIZE + CELL_SIZE * 0.5)
	var pulse := sin(food_pulse_time) * 1.5
	var food_radius := (CELL_SIZE * 0.38) + pulse
	target.draw_circle(food_center, food_radius + 3.0, COLOR_FOOD_GLOW * Color(1, 1, 1, 0.35))
	target.draw_circle(food_center, food_radius, COLOR_FOOD)

	# Yılan çizimi
	for i in range(snake.size()):
		var segment := snake[i]
		var rect := Rect2(
			Vector2(segment.x * CELL_SIZE + 2.0, segment.y * CELL_SIZE + 2.0),
			Vector2(CELL_SIZE - 4.0, CELL_SIZE - 4.0)
		)
		var is_head := (i == 0)
		var fill_color := COLOR_SNAKE_HEAD if is_head else COLOR_SNAKE_BODY
		
		# Köşe yuvarlama efekti için küçük rect
		target.draw_rect(rect, fill_color, true)
		target.draw_rect(rect, COLOR_SNAKE_OUTLINE, false, 1.5)

		# Baş gözleri
		if is_head:
			var eye_color := Color.WHITE
			var pupil_color := Color.BLACK
			var eye1 := food_center
			var eye2 := food_center
			var offset_x := CELL_SIZE * 0.22
			var offset_y := CELL_SIZE * 0.22
			var head_center := Vector2(segment.x * CELL_SIZE + CELL_SIZE * 0.5, segment.y * CELL_SIZE + CELL_SIZE * 0.5)

			if direction == Vector2i.RIGHT:
				eye1 = head_center + Vector2(offset_x, -offset_y)
				eye2 = head_center + Vector2(offset_x, offset_y)
			elif direction == Vector2i.LEFT:
				eye1 = head_center + Vector2(-offset_x, -offset_y)
				eye2 = head_center + Vector2(-offset_x, offset_y)
			elif direction == Vector2i.UP:
				eye1 = head_center + Vector2(-offset_x, -offset_y)
				eye2 = head_center + Vector2(offset_x, -offset_y)
			else: # DOWN
				eye1 = head_center + Vector2(-offset_x, offset_y)
				eye2 = head_center + Vector2(offset_x, offset_y)

			target.draw_circle(eye1, 2.5, eye_color)
			target.draw_circle(eye2, 2.5, eye_color)
			target.draw_circle(eye1, 1.2, pupil_color)
			target.draw_circle(eye2, 1.2, pupil_color)

func _on_restart_button_pressed() -> void:
	start_new_game()
