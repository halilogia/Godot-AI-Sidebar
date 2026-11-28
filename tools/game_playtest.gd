extends SceneTree

## Evrensel oyun test sürücüsü (Godot Playwright / Agent Driver). Sıfır konfigürasyon: herhangi bir Godot 4
## projesinin ana sahnesini açar, InputMap'ten tuşları, sahne ağacından aktör ve butonları keşfeder, gerçek girdi
## göndererek oynar, telemetri ölçer ve playtest_report.json yazar.
##
##   godot --path <proje> -s <bu dosyanın mutlak yolu> -- [anahtar=değer ...]
##
## Anahtarlar: duration=6 (sn)  out=<mutlak klasör>  scenario=<json yolu>  scene=res://x.tscn (ana sahne yerine)
##   shots=3 (otopilot ekran görüntüsü sayısı)  min_fps=15  strict=1 (uyarıları da FAIL say)  seed=1
##   expect_move=1 (aktör girdiyle hareket etmezse FAIL)  size=1280x720
## Senaryo: `scenario=` ya da projede res://playtest_scenario.json. Adımlar: wait, press, hold, release, key, click,
##   screenshot, autopilot, wait_for, expect, expect_moved, scene, log. Senaryo yoksa tek adım: autopilot.
## Pencere olmadan (--headless) ekran görüntüsü alınmaz; FPS anlamsızdır (rapor `fps_meaningful: false`).

const SKIP_TOKENS: Array[String] = ["pause", "menu", "quit", "exit", "escape", "esc", "debug", "console", "fullscreen",
	"screenshot", "restart", "reset", "settings", "save", "load", "cancel", "capture", "record"]
const AIM_TOKENS: Array[String] = ["aim", "look", "cam", "camera", "rotate", "turn", "zoom", "scroll"]
const JUMP_TOKENS: Array[String] = ["jump", "flap", "fly", "thrust", "hop"]
const BAD_BUTTON: Array[String] = ["quit", "exit", "çık", "cik", "kapat", "ayar", "setting", "option", "seçenek", "credit",
	"delete", "sil", "reset", "sıfırla", "erase", "wipe", "mute", "language", "dil", "geri", "back", "store", "shop"]
const GOOD_BUTTON: Array[String] = ["play", "start", "begin", "new", "continue", "resume", "başla", "basla", "oyna", "yeni",
	"devam", "next", "ileri", "ok", "tamam", "accept", "confirm", "ready", "hazır", "fight", "enter", "go", "dive", "select", "seç"]
const DIRS: Array[Vector2] = [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1),
	Vector2(0.7, 0.7), Vector2(-0.7, -0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7)]

class _ErrLogger extends Logger:
	var mutex := Mutex.new()
	var errors: Array[String] = []
	var warnings: int = 0
	var error_count: int = 0
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings += 1
		else:
			error_count += 1
			if errors.size() < 25:
				errors.append("%s:%d %s() %s %s" % [file.get_file(), line, function, code, rationale])
		mutex.unlock()

var _args: Dictionary = {}
var _duration: float = 6.0
var _out_dir: String = ""
var _min_fps: float = 15.0
var _headless: bool = false
var _t0_ms: int = 0
var _frames: int = 0
var _dts: Array[float] = []
var _logger: _ErrLogger
var _held: Dictionary = {}          # action -> kind
var _sim_counts: Dictionary = {}    # action -> sayı
var _acts: Dictionary = {"move": {}, "jump": [], "act": [], "aim": [], "ui": []}
var _buttons: Array[Control] = []
var _click_log: Array[Dictionary] = []
var _click_count: Dictionary = {}   # düğme anahtarı -> tıklama sayısı
var _bodies: Array[Node] = []
var _primary: Node = null
var _primary_rank: int = 99
var _tracked: Dictionary = {}       # instance_id -> {path, class, start, last, dist, dist_input, is3d}
var _scenes: Array[String] = []
var _shots: Array[String] = []
var _checks: Array[Dictionary] = []
var _warns: Array[String] = []
var _node_start: int = 0
var _node_peak: int = 0
var _finished: bool = false
var _stuck_since: float = -1.0
var _stuck_n: int = 0
var _step_log: Array[String] = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_duration = float(_args.get("duration", 6.0))
	_min_fps = float(_args.get("min_fps", 15.0))
	_headless = DisplayServer.get_name() == "headless"
	seed(int(_args.get("seed", 1)))
	_out_dir = str(_args.get("out", ProjectSettings.globalize_path("user://playtest")))
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_logger = _ErrLogger.new()
	OS.add_logger(_logger)
	Input.use_accumulated_input = false
	if str(_args.get("size", "")).contains("x") and not _headless:
		var wh := str(_args["size"]).split("x")
		root.size = Vector2i(int(wh[0]), int(wh[1]))
	_t0_ms = Time.get_ticks_msec()
	_run()

func _run() -> void:
	var scene_path := str(_args.get("scene", ProjectSettings.get_setting("application/run/main_scene", "")))
	var packed: PackedScene = load(scene_path) as PackedScene if scene_path != "" else null
	if packed == null:
		_check("scene_loaded", false, "ana sahne yüklenemedi: '%s'" % scene_path)
		_finish()
		return
	var inst := packed.instantiate()
	root.add_child(inst)
	current_scene = inst
	_check("scene_loaded", true, scene_path)
	await process_frame
	await process_frame
	_node_start = _node_count()
	_discover()

	var steps: Array = _load_steps()
	if steps.is_empty():
		var shots := int(_args.get("shots", 3))
		steps = [{"autopilot": _duration, "shots": shots}]
	for s in steps:
		if _finished:
			return
		if s is Dictionary:
			await _exec_step(s as Dictionary)
	await _sleep(0.3)
	_finish()

func _process(delta: float) -> bool:
	_frames += 1
	if _frames > 3 and delta > 0.0:
		_dts.append(delta)
	_node_peak = maxi(_node_peak, _node_count()) if _frames % 15 == 0 else _node_peak
	var moving := _move_held()
	for id in _tracked:
		var t: Dictionary = _tracked[id]
		var n := instance_from_id(int(id)) as Node
		if n == null:
			continue
		var p := _pos(n)
		var d := (t["last"] as Vector3).distance_to(p)
		t["dist"] = float(t["dist"]) + d
		if moving:
			t["dist_input"] = float(t["dist_input"]) + d
		t["last"] = p
	return false

# ---------------------------------------------------------------- senaryo

func _load_steps() -> Array:
	var path := str(_args.get("scenario", ""))
	if path == "" and FileAccess.file_exists("res://playtest_scenario.json"):
		path = "res://playtest_scenario.json"
	if path == "":
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_check("scenario_loaded", false, "açılamadı: " + path)
		return []
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Array:
		return data as Array
	if data is Dictionary and (data as Dictionary).has("steps"):
		return (data as Dictionary)["steps"] as Array
	_check("scenario_loaded", false, "geçersiz JSON: " + path)
	return []

func _exec_step(s: Dictionary) -> void:
	_step_log.append(JSON.stringify(s))
	if s.has("press") or s.has("hold") or s.has("key"):
		# Kare başına hizala: screenshot (frame_post_draw) veya zamanlayıcıdan sonra basılan tuş, o karenin
		# _process'i bitmiş olduğundan `is_action_just_pressed` tarafından hiç görülmezdi.
		await process_frame
	if s.has("wait"):
		await _sleep(float(s["wait"]))
	elif s.has("autopilot"):
		await _autopilot(float(s["autopilot"]), int(s.get("shots", 0)))
	elif s.has("press"):
		await _tap(str(s["press"]), float(s.get("hold", 0.12)))
	elif s.has("hold"):
		_act_down(str(s["hold"]), "move")
		await _sleep(float(s.get("for", s.get("duration", 0.5))))
		_act_up(str(s["hold"]))
	elif s.has("release"):
		_act_up(str(s["release"]))
	elif s.has("key"):
		await _key(str(s["key"]), float(s.get("hold", 0.12)))
	elif s.has("click"):
		var target: Variant = s["click"]
		var ok := await _click_target(target)
		_check("click " + str(target), ok, "" if ok else "hedef bulunamadı")
	elif s.has("screenshot"):
		await _shot(str(s["screenshot"]))
	elif s.has("wait_for"):
		var ok := await _wait_for(str(s["wait_for"]), float(s.get("timeout", 5.0)))
		_check("wait_for " + str(s["wait_for"]), ok, "" if ok else "zaman aşımı")
	elif s.has("expect"):
		var ok := _find_node(str(s["expect"])) != null
		_check("expect " + str(s["expect"]), ok, "" if ok else "bulunamadı")
	elif s.has("expect_moved"):
		var moved := _actor_moved()
		_check("expect_moved", moved == bool(s["expect_moved"]), "actor_moved=%s" % moved)
	elif s.has("scene"):
		change_scene_to_file(str(s["scene"]))
		await _sleep(0.5)
		_discover()
	elif s.has("log"):
		print("[playtest] ", s["log"])

# ---------------------------------------------------------------- otopilot

func _autopilot(sec: float, shots: int) -> void:
	var end := _now() + sec
	var shot_at: Array[float] = []
	for i in shots:
		shot_at.append(_now() + sec * (float(i) + 0.6) / float(shots))
	var tick := 0
	var shot_i := 0
	while _now() < end and not _finished:
		_discover()
		if shot_at.size() > 0 and shot_i < shot_at.size() and _now() >= shot_at[shot_i]:
			shot_i += 1
			await _shot("auto_%02d" % shot_i)
		var clicked := false
		if _should_click():
			clicked = await _click_best()
		if clicked:
			_release_all()
			await _sleep(0.6)
		else:
			await _gameplay_tick(tick)
		tick += 1
	_release_all()
	while shot_i < shots:
		shot_i += 1
		await _shot("auto_%02d" % shot_i)

## Aktör da buton da yokken (sinematik, diyalog, yükleme) 2 sn sonra ilerletme tuşlarını sırayla dener.
func _stuck_tick() -> bool:
	if _primary != null or not _buttons.is_empty():
		_stuck_since = -1.0
		return false
	if _stuck_since < 0.0:
		_stuck_since = _now()
	if _now() - _stuck_since < 2.0:
		return false
	_stuck_n += 1
	match _stuck_n % 5:
		0:
			if InputMap.has_action("ui_accept"):
				await _tap("ui_accept", 0.1)
		1:
			var r := root.get_visible_rect()
			await _click_at(r.position + r.size * 0.5)
		2: await _key("Enter", 0.1)
		3: await _key("Space", 0.1)
		4: await _key("Escape", 0.1)
	await _sleep(0.4)
	return true

func _gameplay_tick(tick: int) -> void:
	if await _stuck_tick():
		return
	var moves: Dictionary = _acts["move"]
	if not moves.is_empty():
		_set_move(DIRS[(tick / 3) % DIRS.size()])
	var pool: Array = []
	pool.append_array(_acts["act"] as Array)
	pool.append_array(_acts["jump"] as Array)
	if pool.is_empty():
		pool.append_array(_acts["ui"] as Array)
	_pointer_move(tick)
	if pool.size() > 0:
		await _tap(str(pool[tick % pool.size()]), 0.1)
		await _sleep(0.15)
	else:
		await _sleep(0.3)

func _set_move(dir: Vector2) -> void:
	var moves: Dictionary = _acts["move"]
	for a in moves:
		var v: Vector2 = moves[a]
		if dir.normalized().dot(v) > 0.5:
			if not _held.has(a):
				_act_down(str(a), "move")
		else:
			_act_up(str(a))

func _pointer_move(tick: int) -> void:
	var r := root.get_visible_rect()
	var p := r.position + r.size * Vector2(0.5 + 0.3 * sin(tick * 0.7), 0.5 + 0.3 * cos(tick * 0.5))
	var m := InputEventMouseMotion.new()
	m.position = root.get_final_transform() * p
	m.global_position = m.position
	Input.parse_input_event(m)

# ---------------------------------------------------------------- girdi

func _act_down(action: String, kind: String) -> void:
	if not InputMap.has_action(action):
		return
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	e.strength = 1.0
	Input.parse_input_event(e)
	if not Input.is_action_pressed(action):
		Input.action_press(action)
	_held[action] = kind
	_sim_counts[action] = int(_sim_counts.get(action, 0)) + 1

func _act_up(action: String) -> void:
	if not _held.has(action):
		return
	var e := InputEventAction.new()
	e.action = action
	e.pressed = false
	Input.parse_input_event(e)
	if Input.is_action_pressed(action):
		Input.action_release(action)
	_held.erase(action)

func _release_all() -> void:
	for a in _held.keys():
		_act_up(str(a))

func _tap(action: String, hold: float) -> void:
	_act_down(action, "tap")
	await _sleep(hold)
	_act_up(action)

func _key(key_name: String, hold: float) -> void:
	var code := OS.find_keycode_from_string(key_name)
	if code == KEY_NONE:
		_check("key " + key_name, false, "bilinmeyen tuş")
		return
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		if down:
			await _sleep(hold)
	_sim_counts["key:" + key_name] = int(_sim_counts.get("key:" + key_name, 0)) + 1

func _move_held() -> bool:
	for a in _held:
		if _held[a] == "move":
			return true
	return false

# ---------------------------------------------------------------- tıklama

func _should_click() -> bool:
	if _buttons.is_empty() or _click_log.size() >= 14:
		return false
	if _primary == null:
		return true
	# Aktör varken yalnız "başla/devam" gibi olumlu bir buton ve aktör kıpırdamıyorsa tıkla.
	return _best_button(true) != null and not _actor_moved()

func _click_best() -> bool:
	var b := _best_button(_primary != null)
	if b == null:
		return false
	return await _click_control(b)

func _best_button(positive_only: bool) -> Control:
	var best: Control = null
	var best_key := Vector2(99, 99)
	for b in _buttons:
		if not is_instance_valid(b):
			continue
		var label := _label_of(b).to_lower()
		if _has_any(label, BAD_BUTTON):
			continue
		var good := _has_any(label, GOOD_BUTTON)
		if positive_only and not good:
			continue
		var key := Vector2(0.0 if good else 1.0, float(_click_count.get(_btn_key(b), 0)))
		if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
			best = b
			best_key = key
	return best

func _click_target(target: Variant) -> bool:
	if target is Array and (target as Array).size() >= 2:
		var t := target as Array
		await _click_at(Vector2(float(t[0]), float(t[1])))
		return true
	var n := _find_node(str(target), true)
	if n is Control:
		return await _click_control(n as Control)
	return false

func _click_control(c: Control) -> bool:
	var label := _label_of(c)
	var cpath := str(c.get_path())
	var hit := [false]
	var cb := func() -> void: hit[0] = true
	var clickable := c.has_signal("pressed")
	if clickable:
		c.connect("pressed", cb, CONNECT_ONE_SHOT)
		_click_count[_btn_key(c)] = int(_click_count.get(_btn_key(c), 0)) + 1
	await _click_at(c.get_global_transform_with_canvas() * (c.size * 0.5))
	var method := "mouse"
	if clickable and is_instance_valid(c) and not hit[0]:
		if c.is_connected("pressed", cb):
			c.disconnect("pressed", cb)
		c.emit_signal("pressed")
		method = "emit"
	_click_log.append({"target": label, "path": cpath, "method": method})
	_sim_counts["click"] = int(_sim_counts.get("click", 0)) + 1
	await _sleep(0.15)
	return true

func _click_at(vp_pos: Vector2) -> void:
	var win := root.get_final_transform() * vp_pos
	var m := InputEventMouseMotion.new()
	m.position = win
	m.global_position = win
	Input.parse_input_event(m)
	await process_frame
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = win
		e.global_position = win
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(e)
		await process_frame
		await process_frame

# ---------------------------------------------------------------- keşif

func _discover() -> void:
	_discover_actions()
	_buttons.clear()
	_bodies.clear()
	var stack: Array[Node] = [root]
	var visited := 0
	while not stack.is_empty() and visited < 20000:
		var n: Node = stack.pop_back()
		visited += 1
		if n is CanvasItem and not (n as CanvasItem).visible:
			continue
		if _is_clickable(n):
			_buttons.append(n as Control)
		elif n is CharacterBody2D or n is CharacterBody3D or n is RigidBody2D or n is RigidBody3D:
			_bodies.append(n)
		elif (n is Node2D or n is Node3D) and n.is_in_group("player"):
			# Kendi hareket kodlu (fiziksiz) aktörler: "player" grubundaysa sayılır.
			_bodies.append(n)
		for c in n.get_children():
			stack.append(c)
	_pick_primary()
	var cs := current_scene
	if cs != null and (_scenes.is_empty() or _scenes[-1] != cs.scene_file_path):
		_scenes.append(cs.scene_file_path)

func _discover_actions() -> void:
	var moves: Dictionary = {}
	var jump: Array = []
	var act: Array = []
	var aim: Array = []
	var ui: Array = []
	for a in InputMap.get_actions():
		var name := String(a)
		var tokens := name.to_lower().replace("-", "_").replace(" ", "_").split("_", false)
		if name.begins_with("ui_"):
			ui.append(name)
			continue
		if _tokens_have(tokens, SKIP_TOKENS):
			continue
		if _tokens_have(tokens, AIM_TOKENS):
			aim.append(name)
			continue
		var v := _dir_of(tokens)
		if v != Vector2.ZERO:
			moves[name] = v
		elif _tokens_have(tokens, JUMP_TOKENS):
			jump.append(name)
		else:
			act.append(name)
	if moves.is_empty():
		var fallback := {"ui_left": Vector2(-1, 0), "ui_right": Vector2(1, 0), "ui_up": Vector2(0, -1), "ui_down": Vector2(0, 1)}
		for k in fallback:
			if InputMap.has_action(k):
				moves[k] = fallback[k]
	if act.is_empty() and jump.is_empty() and InputMap.has_action("ui_accept"):
		act.append("ui_accept")
	_acts = {"move": moves, "jump": jump, "act": act, "aim": aim, "ui": ui}

func _dir_of(tokens: PackedStringArray) -> Vector2:
	var v := Vector2.ZERO
	for t in tokens:
		match t:
			"left", "west": v.x -= 1
			"right", "east": v.x += 1
			"up", "forward", "fwd", "north": v.y -= 1
			"down", "backward", "back", "south": v.y += 1
	return v

func _pick_primary() -> void:
	var best: Node = null
	var best_rank := 99
	for n in _bodies:
		var rank := 3
		var lname := n.name.to_lower()
		if n.is_in_group("player"):
			rank = 0
		elif lname.contains("player") or lname.contains("hero"):
			rank = 1
		elif n is CharacterBody2D or n is CharacterBody3D:
			rank = 2
		if rank < best_rank:
			best = n
			best_rank = rank
	if best == null:
		return
	if _primary == null or not is_instance_valid(_primary) or best_rank < _primary_rank:
		_primary = best
		_primary_rank = best_rank
		var id := best.get_instance_id()
		if not _tracked.has(id):
			var p := _pos(best)
			_tracked[id] = {"path": str(best.get_path()), "class": best.get_class(), "start": p, "last": p,
				"dist": 0.0, "dist_input": 0.0, "is3d": best is Node3D}

func _find_node(query: String, controls_only: bool = false) -> Node:
	var q := query.to_lower()
	var stack: Array[Node] = [root]
	var fallback: Node = null
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).visible:
			continue
		if not controls_only or n is Control:
			var text := _label_of(n).to_lower()
			if n.name.to_lower() == q or str(n.get_path()).to_lower().ends_with(q) or (text != "" and text.contains(q)):
				if n.has_signal("pressed"):
					return n
				if fallback == null:
					fallback = n
		for c in n.get_children():
			stack.append(c)
	return fallback

## Tıklanabilir: BaseButton ya da `pressed` sinyali olan özel Control (pixel_button gibi), görünür ve etkin.
func _is_clickable(n: Node) -> bool:
	if not (n is Control) or not n.has_signal("pressed"):
		return false
	var c := n as Control
	if c.size.x < 2.0 or not c.is_visible_in_tree() or c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	if c.modulate.a < 0.1 or c.self_modulate.a < 0.1:
		return false
	if c is BaseButton:
		var b := c as BaseButton
		if b.disabled or b.toggle_mode or b is CheckBox or b is CheckButton or b is OptionButton or b is MenuButton:
			return false
	elif c.get("disabled") == true:
		return false
	return true

func _wait_for(query: String, timeout: float) -> bool:
	var end := _now() + timeout
	while _now() < end:
		if _find_node(query) != null:
			return true
		await _sleep(0.2)
	return false

# ---------------------------------------------------------------- ölçüm / yardımcılar

func _shot(shot_name: String) -> void:
	if _headless:
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		return
	var path := _out_dir.path_join(shot_name + ".png")
	if img.save_png(path) == OK:
		_shots.append(path)

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	_checks.append({"name": check_name, "pass": ok, "detail": detail})

func _actor_moved() -> bool:
	for id in _tracked:
		var t: Dictionary = _tracked[id]
		var eps := 0.1 if bool(t["is3d"]) else 1.0
		if float(t["dist_input"]) > eps:
			return true
	return false

func _now() -> float:
	return float(Time.get_ticks_msec() - _t0_ms) / 1000.0

func _node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

func _pos(n: Node) -> Vector3:
	if n is Node2D:
		var p2 := (n as Node2D).global_position
		return Vector3(p2.x, p2.y, 0.0)
	if n is Node3D:
		return (n as Node3D).global_position
	return Vector3.ZERO

func _sleep(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		if _now() > float(_args.get("timeout", 120.0)):
			_check("timeout", false, "genel zaman sınırı aşıldı")
			_finish()
			return

func _label_of(n: Node) -> String:
	var t: Variant = n.get("text")
	if t is String and (t as String) != "":
		return t as String
	return str(n.name)

func _btn_key(b: Node) -> String:
	return "%s|%s" % [str(b.get_path()), _label_of(b)]

func _has_any(label: String, words: Array[String]) -> bool:
	for w in words:
		if label.contains(w):
			return true
	return false

func _tokens_have(tokens: PackedStringArray, words: Array[String]) -> bool:
	for t in tokens:
		if words.has(t):
			return true
	return false

# ---------------------------------------------------------------- rapor

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_release_all()
	var wall := _now()
	var fps_avg := 0.0
	var fps_min := 0.0
	var fps_p1 := 0.0
	if _dts.size() > 0:
		var sorted := _dts.duplicate()
		sorted.sort()
		var total := 0.0
		for d in _dts:
			total += d
		fps_avg = float(_dts.size()) / total
		fps_min = 1.0 / sorted[-1]
		fps_p1 = 1.0 / sorted[mini(sorted.size() - 1, int(sorted.size() * 0.99))]
	var err_n := _logger.error_count
	_check("no_script_errors", err_n == 0, "%d hata" % err_n)
	_check("frames_advanced", _frames >= 10, "%d kare" % _frames)
	if not _headless:
		_check("fps_ok", fps_avg >= _min_fps, "ort. %.1f (eşik %.0f)" % [fps_avg, _min_fps])
	var moved := _actor_moved()
	var move_actions: Dictionary = _acts["move"]
	if _primary == null:
		_warns.append("aktör (CharacterBody/RigidBody ya da \"player\" grubunda Node2D/3D) bulunamadı: menü/UI sahnesi olabilir")
	elif not moved and not move_actions.is_empty():
		_warns.append("aktör girdiyle hareket etmedi (actor_moved=false)")
		if str(_args.get("expect_move", "")) != "":
			_check("actor_moved", false, "beklenen hareket yok")
	if _acts["move"] == {} and (_acts["act"] as Array).is_empty() and (_acts["jump"] as Array).is_empty():
		_warns.append("keşfedilen oynanış girdisi yok")
	if _headless:
		_warns.append("headless: ekran görüntüsü alınmadı, FPS anlamsız")
	elif _shots.is_empty():
		_warns.append("ekran görüntüsü alınmadı")
	if str(_args.get("strict", "")) != "" and _warns.size() > 0:
		_check("strict_warnings", false, "; ".join(_warns))
	var failed: Array[String] = []
	for c in _checks:
		if not bool(c["pass"]):
			failed.append("%s (%s)" % [c["name"], c["detail"]])
	var verdict := "PASS" if failed.is_empty() else "FAIL"

	var actors: Array = []
	for id in _tracked:
		var t: Dictionary = _tracked[id]
		actors.append({"path": t["path"], "class": t["class"], "distance_total": snappedf(float(t["dist"]), 0.01),
			"distance_while_input": snappedf(float(t["dist_input"]), 0.01),
			"displacement": snappedf((t["last"] as Vector3).distance_to(t["start"] as Vector3), 0.01)})
	var report := {
		"verdict": verdict,
		"failed_checks": failed,
		"warnings": _warns,
		"project": str(ProjectSettings.get_setting("application/config/name", "")),
		"godot": Engine.get_version_info()["string"],
		"headless": _headless,
		"duration_s": snappedf(wall, 0.01),
		"frames": _frames,
		"fps": {"avg": snappedf(fps_avg, 0.1), "min": snappedf(fps_min, 0.1), "p1_low": snappedf(fps_p1, 0.1),
			"fps_meaningful": not _headless},
		"actor_moved": moved,
		"actors": actors,
		"actions_simulated": {"total": _sum(_sim_counts), "by_action": _sim_counts},
		"discovered_inputs": {"move": (_acts["move"] as Dictionary).keys(), "jump": _acts["jump"], "act": _acts["act"],
			"aim": _acts["aim"], "ui": (_acts["ui"] as Array).size()},
		"clicks": _click_log,
		"scenes_visited": _scenes,
		"nodes": {"start": _node_start, "end": _node_count(), "peak": maxi(_node_peak, _node_count())},
		"errors": {"count": err_n, "warnings": _logger.warnings, "samples": _logger.errors},
		"screenshots": _shots,
		"checks": _checks,
		"steps": _step_log,
	}
	var path := _out_dir.path_join("playtest_report.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[playtest] VERDICT=%s frames=%d fps=%.1f actor_moved=%s actions=%d errors=%d report=%s" %
		[verdict, _frames, fps_avg, moved, _sum(_sim_counts), err_n, path])
	OS.remove_logger(_logger)
	quit(0 if verdict == "PASS" else 1)

func _sum(d: Dictionary) -> int:
	var s := 0
	for k in d:
		s += int(d[k])
	return s
