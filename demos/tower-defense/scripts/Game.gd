class_name Game
extends Node2D

signal stats_changed(gold: int, lives: int, wave: int)
signal selection_changed(sel: Dictionary)
signal game_over(won: bool)

const BUILD_KINDS: Array = [
	TowerData.Kind.ARCHER, TowerData.Kind.CANNON, TowerData.Kind.FROST,
]

var gold := GameConfig.START_GOLD
var lives := GameConfig.START_LIVES
var wave := 0
var enemies: Array = []
var towers: Array = []
var bullets: Array = []
var points: Array = []
var occupied: Dictionary = {}
var selected_cell := Vector2i(-1, -1)
var build_kind: TowerData.Kind = TowerData.Kind.ARCHER
var selected_tower: Tower = null
var hover_cell := Vector2i(-1, -1)
var running := true
var wave_active := false
var spawn_timer := 0.0
var to_spawn: Array = []
var spawn_interval := 0.9
var effects: Effects

func _ready() -> void:
	effects = Effects.new()
	add_child(effects)
	_build_path()
	var hud := get_node_or_null("Hud") as Hud
	if hud != null:
		hud.bind(self)
	queue_redraw()

func _build_path() -> void:
	points.clear()
	for c in GameConfig.PATH_CELLS:
		points.append(GameConfig.ORIGIN + Vector2(c.x * GameConfig.TILE + GameConfig.TILE * 0.5,
			c.y * GameConfig.TILE + GameConfig.TILE * 0.5))

func cell_to_pos(c: Vector2i) -> Vector2:
	return GameConfig.ORIGIN + Vector2(c.x * GameConfig.TILE + GameConfig.TILE * 0.5,
		c.y * GameConfig.TILE + GameConfig.TILE * 0.5)

func pos_to_cell(p: Vector2) -> Vector2i:
	var local := p - GameConfig.ORIGIN
	return Vector2i(int(floor(local.x / GameConfig.TILE)), int(floor(local.y / GameConfig.TILE)))

func is_path_cell(c: Vector2i) -> bool:
	for p in GameConfig.PATH_CELLS:
		if p == c:
			return true
	return false

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GameConfig.COLS and c.y < GameConfig.ROWS

# --- input ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_cell = pos_to_cell(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click(pos_to_cell(get_global_mouse_position()))
	elif event.is_action_pressed("start_wave"):
		start_wave()

func _on_click(c: Vector2i) -> void:
	if not running or not in_bounds(c):
		return
	if occupied.has(c):
		selected_tower = occupied[c]
		selected_cell = Vector2i(-1, -1)
		selection_changed.emit(_selection_info())
		queue_redraw()
		return
	selected_tower = null
	selected_cell = c
	selection_changed.emit(_selection_info())
	queue_redraw()

func _selection_info() -> Dictionary:
	if selected_tower != null and is_instance_valid(selected_tower):
		var s: Dictionary = selected_tower.stats()
		return {
			"mode": "tower",
			"name": TowerData.DEFS[selected_tower.kind]["name"],
			"level": selected_tower.level,
			"damage": s["damage"],
			"range": s["range"],
			"rate": s["cooldown"],
			"sell": int(TowerData.DEFS[selected_tower.kind]["cost"] * 0.6 * selected_tower.level),
		}
	if selected_cell.x >= 0:
		var d: Dictionary = TowerData.DEFS[build_kind]
		return {
			"mode": "build",
			"name": d["name"],
			"cost": d["cost"],
			"range": d["range"],
			"damage": d["damage"],
		}
	return {"mode": "none"}

func set_build_kind(k: TowerData.Kind) -> void:
	build_kind = k
	selected_tower = null
	selected_cell = Vector2i(-1, -1)
	selection_changed.emit(_selection_info())
	queue_redraw()

# --- economy / building ---
func can_afford(cost: int) -> bool:
	return gold >= cost

func try_build() -> bool:
	if selected_tower != null and is_instance_valid(selected_tower):
		return _upgrade(selected_tower)
	if selected_cell.x < 0:
		return false
	if is_path_cell(selected_cell):
		effects.spawn_float_text(cell_to_pos(selected_cell), "Yola kule kurulamaz", Palette.DANGER)
		return false
	var d: Dictionary = TowerData.DEFS[build_kind]
	var cost: int = d["cost"]
	if gold < cost:
		effects.spawn_float_text(cell_to_pos(selected_cell), "Altın yetersiz", Palette.DANGER)
		return false
	gold -= cost
	var t := Tower.new()
	t.kind = build_kind
	t.cell = selected_cell
	t.position = cell_to_pos(selected_cell)
	t.refresh()
	add_child(t)
	occupied[selected_cell] = t
	towers.append(t)
	effects.spawn_burst(cell_to_pos(selected_cell), Palette.ACCENT, 10)
	selected_tower = t
	selected_cell = Vector2i(-1, -1)
	stats_changed.emit(gold, lives, wave)
	selection_changed.emit(_selection_info())
	queue_redraw()
	return true

func _upgrade(t: Tower) -> bool:
	if not t.can_upgrade():
		return false
	var cost := t.upgrade_cost()
	if gold < cost:
		effects.spawn_float_text(t.position, "Altın yetersiz", Palette.DANGER)
		return false
	gold -= cost
	t.level += 1
	t.refresh()
	t.cooldown_left = 0.0
	effects.spawn_burst(t.position, Palette.ACCENT, 12)
	effects.spawn_float_text(t.position, "SvL %d" % t.level, Palette.ACCENT)
	stats_changed.emit(gold, lives, wave)
	selection_changed.emit(_selection_info())
	return true

func sell_selected() -> void:
	if selected_tower == null or not is_instance_valid(selected_tower):
		return
	var refund: int = int(TowerData.DEFS[selected_tower.kind]["cost"] * 0.6 * selected_tower.level)
	gold += refund
	effects.spawn_float_text(selected_tower.position, "+%d" % refund, Palette.ACCENT)
	occupied.erase(selected_tower.cell)
	towers.erase(selected_tower)
	selected_tower.queue_free()
	selected_tower = null
	stats_changed.emit(gold, lives, wave)
	selection_changed.emit(_selection_info())
	queue_redraw()

func select_first_tower_of_kind(k: TowerData.Kind) -> void:
	for t in towers:
		if is_instance_valid(t) and t.kind == k:
			selected_tower = t
			selected_cell = Vector2i(-1, -1)
			selection_changed.emit(_selection_info())
			queue_redraw()
			return

# --- waves ---
func start_wave() -> void:
	if wave_active or not running:
		return
	wave += 1
	wave_active = true
	to_spawn.clear()
	var count: int = 6 + wave * 2
	var hp: float = 40.0 + wave * 12.0
	var spd: float = 52.0 + wave * 2.0
	spawn_interval = maxf(0.32, 0.95 - wave * 0.05)
	for i in count:
		to_spawn.append({"hp": hp, "speed": spd, "boss": false})
	var bosses: int = maxi(0, wave / 3)
	for i in bosses:
		to_spawn.append({"hp": hp * 4.0, "speed": spd * 0.65, "boss": true})
	spawn_timer = 0.0
	stats_changed.emit(gold, lives, wave)

func _spawn_enemy(info: Dictionary) -> void:
	var e := Enemy.new()
	e.setup(points, info["hp"], info["speed"], 8 + int(info["hp"] / 12.0), 1)
	e.is_boss = info["boss"]
	e.position = points[0]
	add_child(e)
	enemies.append(e)

# --- main loop ---
func _process(delta: float) -> void:
	if not running:
		return
	if wave_active and to_spawn.size() > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_enemy(to_spawn.pop_front())
			spawn_timer = spawn_interval
	elif wave_active and enemies.is_empty():
		wave_active = false

	for t: Tower in towers:
		if not is_instance_valid(t):
			continue
		if t.cooldown_left > 0.0:
			continue
		var target: Enemy = t.has_target(enemies)
		if target != null:
			t.cooldown_left = float(t.stats()["cooldown"])
			t.recoil = 1.0
			t.muzzle_flash = 1.0
			_fire(t, target)
	queue_redraw()

func _fire(t: Tower, target: Node2D) -> void:
	var s: Dictionary = t.stats()
	var b := Bullet.new()
	b.target = target
	b.damage = s["damage"]
	b.slow = s["slow"]
	b.from_cell = t.cell
	b.position = t.position + Vector2(0, -10)
	b.speed = 260.0 if t.kind == TowerData.Kind.CANNON else 430.0
	add_child(b)
	bullets.append(b)

func _physics_process(delta: float) -> void:
	if not running:
		return
	var keep_b: Array = []
	for b in bullets:
		if not is_instance_valid(b):
			continue
		if b.arrived:
			if b.target != null and is_instance_valid(b.target):
				var t: Enemy = b.target
				if b.slow:
					t.apply_slow(1.8)
				if t.take_damage(b.damage):
					_on_enemy_died(t)
			b.queue_free()
			continue
		keep_b.append(b)
	bullets = keep_b
	var keep_e: Array = []
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if not e.tick_move(points, delta):
			keep_e.append(e)
		else:
			lives -= e.damage
			effects.spawn_burst(e.position, Palette.DANGER, 12)
			stats_changed.emit(gold, lives, wave)
			if lives <= 0:
				lives = 0
				_running_end(false)
			e.queue_free()
	enemies = keep_e
	bullets = keep_b

func _on_enemy_died(e: Enemy) -> void:
	gold += e.reward
	effects.spawn_burst(e.position, Palette.DANGER.lightened(0.2), 10)
	effects.spawn_float_text(e.position, "+%d" % e.reward, Palette.ACCENT)
	stats_changed.emit(gold, lives, wave)

func _running_end(won: bool) -> void:
	if not running:
		return
	running = false
	game_over.emit(won)

# --- drawing ---
func _draw() -> void:
	# sky gradient bands
	for i in 14:
		var t := float(i) / 13.0
		draw_rect(Rect2(0, i * 52.0, 1280, 52.0), Palette.BG_DEEP.lerp(Palette.BG_MID, t))
	draw_circle(Vector2(1090, 120), 150.0, Color(0.95, 0.55, 0.3, 0.10))
	draw_circle(Vector2(1090, 120), 90.0, Color(0.95, 0.6, 0.35, 0.12))

	var field := Rect2(GameConfig.ORIGIN - Vector2(10, 10),
		Vector2(GameConfig.COLS * GameConfig.TILE + 20, GameConfig.ROWS * GameConfig.TILE + 20))
	draw_rect(field.grow(4), Color(0, 0, 0, 0.35))
	draw_rect(field, Palette.SURFACE)

	for y in GameConfig.ROWS:
		for x in GameConfig.COLS:
			var c := Vector2i(x, y)
			var p := cell_to_pos(c)
			var base: Color = Palette.SURFACE if (x + y) % 2 == 0 else Palette.SURFACE.lightened(0.04)
			if is_path_cell(c):
				base = Palette.PATH
			draw_rect(Rect2(p - Vector2(30, 30), Vector2(60, 60)), base)

	# path edge + inner line
	var path_poly := PackedVector2Array()
	for p in points:
		path_poly.append(p)
	if path_poly.size() > 1:
		draw_polyline(path_poly, Palette.PATH_EDGE, 52.0, true)
		draw_polyline(path_poly, Palette.PATH.lightened(0.06), 40.0, true)
		draw_circle(points[0], 22.0, Palette.DANGER.darkened(0.2))
		draw_circle(points[points.size() - 1], 22.0, Palette.PRIMARY.darkened(0.3))
		draw_arc(points[points.size() - 1], 26.0, 0.0, TAU, 24, Color(Palette.PRIMARY.r, Palette.PRIMARY.g, Palette.PRIMARY.b, 0.4), 2.0)

	# hover + selection highlight
	if in_bounds(hover_cell):
		draw_rect(Rect2(cell_to_pos(hover_cell) - Vector2(30, 30), Vector2(60, 60)),
			Color(1, 1, 1, 0.05))
	if in_bounds(selected_cell):
		var d: Dictionary = TowerData.DEFS[build_kind]
		draw_circle(cell_to_pos(selected_cell), float(d["range"]),
			Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.08))
		draw_rect(Rect2(cell_to_pos(selected_cell) - Vector2(30, 30), Vector2(60, 60)),
			Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.9), false, 2.0)
	if selected_tower != null and is_instance_valid(selected_tower):
		draw_arc(selected_tower.global_position, selected_tower.range_px, 0.0, TAU, 48,
			Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.55), 2.0)
		draw_rect(Rect2(selected_tower.position - Vector2(30, 30), Vector2(60, 60)),
			Color(Palette.ACCENT.r, Palette.ACCENT.g, Palette.ACCENT.b, 0.9), false, 2.0)

	# build ghost
	if in_bounds(selected_cell) and selected_tower == null and not occupied.has(selected_cell):
		var gp := cell_to_pos(selected_cell)
		var col: Color = Palette.ACCENT if can_afford(int(TowerData.DEFS[build_kind]["cost"])) else Palette.DANGER
		draw_circle(gp, 19.0, Color(col.r, col.g, col.b, 0.28))
		draw_arc(gp, 19.0, 0.0, TAU, 24, col, 2.0)
