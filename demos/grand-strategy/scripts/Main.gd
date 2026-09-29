extends Node2D

const COLS := 14
const ROWS := 9
const MAP_POS := Vector2(40, 118)
const MAP_SIZE := Vector2(1200, 566)
const ARMY_MOVE_TIME := 0.9

var state: GameState
var prov_owner: Array = []
var dev: Array = []
var names: Array = []
var armies: Array = []
var sel_army := -1
var sel_prov := -1
var flash: Dictionary = {}
var pop: Array = []
var log_lines: Array = ["Ay 1 · Savaş masasına hoş geldiniz."]
var time_acc := 0.0
var anim_t := 0.0
var bg_grad: GradientTexture2D


func _ready() -> void:
	state = GameState.new()
	gen_world()
	_build_bg()
	set_process(true)


func gen_world() -> void:
	prov_owner.clear()
	dev.clear()
	names.clear()
	for y in ROWS:
		for x in COLS:
			var o := 2
			if x <= 3:
				o = 0
			elif x >= 10:
				o = 1
			elif x == 6 and y >= 5:
				o = 0
			elif x == 7 and y <= 2:
				o = 1
			prov_owner.append(o)
			dev.append(randi_range(6, 20))
	var pool := ["Karaova", "Demir Geçit", "Yeldeğirmeni", "Bozkaya", "Akçaybaşı", "Taşkent", "Gölbaşı", "Kızılova", "Zeytinburnu", "Sarıdere"]
	for i in prov_owner.size():
		names.append(pool[i % pool.size()])
	armies = [
		{"name": "Kuzey Ordusu", "prov": idx(2, 2), "from": Vector2.ZERO, "t": 1.0, "target": -1, "str": 100.0, "player": true, "color": Palette.PAPER},
		{"name": "Hasım Ordusu", "prov": idx(11, 6), "from": Vector2.ZERO, "t": 1.0, "target": -1, "str": 80.0, "player": false, "color": Palette.DANGER},
	]


func idx(x: int, y: int) -> int:
	return y * COLS + x


func _build_bg() -> void:
	var g := Gradient.new()
	g.set_color(0, Palette.BG_DEEP.lightened(0.12))
	g.set_color(1, Palette.BG_DEEP)
	bg_grad = GradientTexture2D.new()
	bg_grad.gradient = g
	bg_grad.fill_from = Vector2(0, 0)
	bg_grad.fill_to = Vector2(0, 1)
	bg_grad.width = 1280
	bg_grad.height = 720
	var bg := TextureRect.new()
	bg.texture = bg_grad
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -10
	add_child(bg)


func cell_rect(i: int) -> Rect2:
	var x := i % COLS
	var y := i / COLS
	var w := MAP_SIZE.x / COLS
	var h := MAP_SIZE.y / ROWS
	return Rect2(MAP_POS + Vector2(x * w, y * h) + Vector2(2, 2), Vector2(w - 4, h - 4))


func cell_center(i: int) -> Vector2:
	return cell_rect(i).get_center()


func _process(delta: float) -> void:
	anim_t += delta
	time_acc += delta
	if time_acc >= GameState.TICK_SECONDS:
		time_acc -= GameState.TICK_SECONDS
		_tick()
	for a in armies:
		if a["t"] < 1.0:
			a["t"] = min(1.0, a["t"] + delta / ARMY_MOVE_TIME)
			if a["t"] >= 1.0 and a["target"] >= 0:
				_arrive(a)
	queue_redraw()


func _tick() -> void:
	state.month += 1
	var income := 0.0
	var mp := 0.0
	for i in dev.size():
		if prov_owner[i] == 0:
			income += dev[i] * 0.06
			mp += dev[i] * 0.05
	state.gold += int(income)
	state.manpower += int(mp)
	state.political_power = min(100.0, state.political_power + 0.4)
	_ai()
	for i in dev.size():
		if prov_owner[i] == 0:
			dev[i] += 0.02
	queue_redraw()


func _ai() -> void:
	for k in armies.size():
		var a: Dictionary = armies[k]
		if a["player"] or a["t"] < 1.0 or randf() > 0.35:
			continue
		var from: int = a["prov"]
		var from_x := from % COLS
		var best := -1
		var bd := 99
		for nx in [from_x - 1, from_x, from_x + 1]:
			if nx < 0 or nx >= COLS:
				continue
			for ny in [from / COLS - 1, from / COLS, from / COLS + 1]:
				if ny < 0 or ny >= ROWS:
					continue
				var j := idx(nx, ny)
				if prov_owner[j] == 0 and abs(nx - from_x) + abs(ny - from / COLS) < bd:
					bd = abs(nx - from_x) + abs(ny - from / COLS)
					best = j
		if best >= 0:
			_order_move(k, best)


func _order_move(ai: int, target: int) -> void:
	var a: Dictionary = armies[ai]
	if target == a["prov"]:
		return
	a["from"] = cell_center(a["prov"])
	a["target"] = target
	a["t"] = 0.0
	sel_army = -1
	_log("Emir: %s -> %s" % [a["name"], names[target]])


func _arrive(a: Dictionary) -> void:
	var t: int = a["target"]
	a["prov"] = t
	var enemy := -1
	for k in armies.size():
		if k != armies.find(a) and not armies[k]["player"] and armies[k]["prov"] == t and armies[k]["t"] >= 1.0:
			enemy = k
	if enemy >= 0:
		_battle(a, armies[enemy])
	a["target"] = -1


func _battle(mine: Dictionary, theirs: Dictionary) -> void:
	var roll := randf() * 0.4 + 0.8
	mine["str"] = max(5.0, mine["str"] - theirs["str"] * 0.5 * roll)
	theirs["str"] = max(5.0, theirs["str"] - mine["str"] * 0.35 * roll)
	flash = {"prov": mine["prov"], "t": 0.12, "win": mine["str"] >= theirs["str"]}
	if mine["str"] >= theirs["str"]:
		prov_owner[mine["prov"]] = 0 if mine["player"] else 1
		_log("Savaş: %s kazandı! %s alındı." % [mine["name"], names[mine["prov"]]])
	else:
		var wp: int = theirs["prov"]
		prov_owner[wp] = 1 if not mine["player"] else 0
		mine["prov"] = theirs["prov"] if mine["player"] else mine["prov"]
		_log("Savaş: %s savunmayı başardı." % theirs["name"])


func _log(t: String) -> void:
	log_lines.append("Ay %d · %s" % [state.month, t])
	if log_lines.size() > 4:
		log_lines.pop_front()


func _text(pos: Vector2, s: String, size: int, col: Color, center := false) -> void:
	var f := ThemeDB.fallback_font
	if center:
		draw_string(f, pos - Vector2(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	else:
		draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _panel(r: Rect2, col: Color) -> void:
	draw_rect(r, col, true)
	draw_rect(r, Palette.ACCENT.darkened(0.35), false, 2.0)


func _draw() -> void:
	# top HUD
	_panel(Rect2(0, 0, 1280, 100), Palette.SURFACE)
	_text(Vector2(28, 44), "AY %d" % state.month, 32, Palette.ACCENT)
	var stats := [
		["Altın", str(state.gold)],
		["İnsan Gücü", str(state.manpower)],
		["Siyaset", str(int(state.political_power))],
		["Toprak", str(_count_own()) + " eyalet"],
	]
	var x := 220.0
	for s in stats:
		_text(Vector2(x, 36), s[0], 16, Palette.PAPER.darkened(0.35))
		_text(Vector2(x, 66), s[1], 20, Palette.PAPER)
		x += 200
	_text(Vector2(1096, 30), "Nasıl oynanır", 16, Palette.ACCENT)
	_text(Vector2(1096, 56), "Ordunu seç,", 14, Palette.PAPER.darkened(0.3))
	_text(Vector2(1096, 76), "hedefe tıkla", 14, Palette.PAPER.darkened(0.3))

	# map
	for i in prov_owner.size():
		var r := cell_rect(i)
		var base := Palette.NEUTRAL_LAND
		if prov_owner[i] == 0:
			base = Palette.PRIMARY
		elif prov_owner[i] == 1:
			base = Palette.DANGER.darkened(0.15)
		var shade := base.darkened(float(i % 3) * 0.06)
		if i == sel_prov:
			var pulse := 0.5 + 0.5 * sin(anim_t * 5.0)
			shade = shade.lightened(0.10 + 0.12 * pulse)
		draw_rect(r, Palette.BG_DEEP, true)
		draw_rect(Rect2(r.position, r.size - Vector2(3, 3)), shade, true)
		_text(r.get_center() + Vector2(0, -2), str(int(dev[i])), 16, Palette.PAPER.darkened(0.2), true)
		_text(r.get_center() + Vector2(0, 20), str(names[i]), 12, Palette.PAPER.darkened(0.45), true)

	# battle flash
	if not flash.is_empty() and flash["t"] > 0.0:
		flash["t"] = max(0.0, float(flash["t"]) - get_process_delta_time())
		var c: Color = Palette.ACCENT if flash["win"] else Palette.PAPER
		draw_rect(cell_rect(flash["prov"]), Color(c, 0.55), true)

	# armies
	for a in armies:
		var pos: Vector2 = a["from"].lerp(cell_center(a["target"] if a["target"] >= 0 else a["prov"]), float(a["t"]))
		var col: Color = Palette.PAPER if a["player"] else Palette.DANGER.lightened(0.25)
		if sel_army >= 0 and armies[sel_army] == a:
			col = Palette.ACCENT
		draw_circle(pos + Vector2(0, 3), 15, Color(0, 0, 0, 0.35))
		draw_circle(pos, 14, col)
		# silhouette: own = up banner, enemy = down banner
		var s := 1.0 if a["player"] else -1.0
		var tip := pos + Vector2(0, -9 * s)
		draw_colored_polygon(PackedVector2Array([pos + Vector2(-7, 6 * s), pos + Vector2(7, 6 * s), tip]), Palette.BG_DEEP)
		draw_arc(pos, 15, 0, TAU, 24, Palette.BG_DEEP, 2.0)
		var w := 22.0 * (float(a["str"]) / 100.0)
		draw_rect(Rect2(pos.x - 11, pos.y + 17, 22, 4), Palette.BG_DEEP, true)
		draw_rect(Rect2(pos.x - 11, pos.y + 17, w, 4), col, true)

	# log panel
	var lp := Rect2(40, MAP_POS.y + MAP_SIZE.y + 6, 1200, 26)
	_panel(lp, Palette.SURFACE)
	if log_lines.size() > 0:
		_text(Vector2(54, lp.position.y + 19), str(log_lines[log_lines.size() - 1]), 16, Palette.PAPER)


func _count_own() -> int:
	var c := 0
	for o in prov_owner:
		if o == 0:
			c += 1
	return c


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = ev.position
		if p.y > MAP_POS.y - 10 and p.y < MAP_POS.y + MAP_SIZE.y + 10:
			var x := int((p.x - MAP_POS.x) / (MAP_SIZE.x / COLS))
			var y := int((p.y - MAP_POS.y) / (MAP_SIZE.y / ROWS))
			if x >= 0 and x < COLS and y >= 0 and y < ROWS:
				_click(idx(x, y))


func _click(i: int) -> void:
	sel_prov = i
	var found := -1
	for k in armies.size():
		if armies[k]["player"] and armies[k]["prov"] == i and armies[k]["t"] >= 1.0:
			found = k
	if found >= 0:
		sel_army = found
		_log("%s seçildi (%s)." % [armies[found]["name"], names[i]])
		return
	if sel_army >= 0 and armies[sel_army]["t"] >= 1.0:
		_order_move(sel_army, i)
		return
	var t := "tarafsız"
	if prov_owner[i] == 0:
		t = "senin toprağın"
	elif prov_owner[i] == 1:
		t = "düşman toprağı"
	_log("%s: %s" % [names[i], t])
