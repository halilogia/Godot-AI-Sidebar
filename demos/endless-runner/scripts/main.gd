extends Node2D
class_name Main

const GROUND_Y := 540.0
const VIEW_W := 1280.0
const VIEW_H := 720.0
const BAND_H := 180.0

var speed := 520.0
var speed_target := 520.0
var distance := 0.0
var coins := 0
var best := 0
var running := false
var dead := false
var shake := 0.0
var spawn_x := 1400.0
var next_spawn := 900.0
var skyline_offset := 0.0
var skyline_seed := 0

@onready var world: Node2D = $World
@onready var player: Player = $World/Player

var distance_label: Label
var coin_label: Label
var best_label: Label
var title_panel: PanelContainer
var gameover_panel: PanelContainer
var go_score: Label
var go_coins: Label
var go_best: Label
var flash_rect: ColorRect
var ui: UIRoot


func _ready() -> void:
	randomize()
	skyline_seed = randi()
	ui = $HUD/Root
	distance_label = ui.distance_label
	coin_label = ui.coin_label
	best_label = ui.best_label
	title_panel = ui.title_panel
	gameover_panel = ui.gameover_panel
	go_score = ui.go_score
	go_coins = ui.go_coins
	go_best = ui.go_best
	flash_rect = ui.flash_rect
	_setup_input()
	var cfg := ConfigFile.new()
	if cfg.load("user://neondash.cfg") == OK:
		best = int(cfg.get_value("run", "best", 0))
	best_label.text = "EN İYİ  %d m" % best
	title_panel.visible = true
	gameover_panel.visible = false
	player.position = Vector2(300.0, GROUND_Y - 40.0)
	player.hit.connect(_on_player_hit)
	queue_redraw()


func _process(delta: float) -> void:
	skyline_offset = fmod(skyline_offset + speed * delta * 0.15, 160.0)
	shake = maxf(0.0, shake - delta * 30.0)
	position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))

	if not running or dead:
		queue_redraw()
		return

	speed_target = 520.0 + minf(distance * 1.1, 430.0)
	speed = lerpf(speed, speed_target, delta * 0.4)
	var dx := speed * delta
	distance += dx * 0.06
	_scroll(dx)
	_spawn_logic()
	_update_hud()
	queue_redraw()


func _scroll(dx: float) -> void:
	for child in world.get_children():
		if child == player:
			continue
		if child.has_method("queue_free") and child.get_meta("scroller", false):
			child.position.x -= dx
			if child.position.x < -300.0:
				child.queue_free()


func _spawn_logic() -> void:
	if distance * 16.0 < next_spawn:
		return
	next_spawn = distance * 16.0 + randf_range(340.0, 620.0)
	_spawn_wave()


func _spawn_wave() -> void:
	var roll := randf()
	if roll < 0.28:
		_spawn_drone()
	elif roll < 0.45:
		_spawn_coin_line(4)
		_spawn_spike()
	else:
		_spawn_spike()
		if randf() < 0.55:
			_spawn_coin_line(3, -60.0)


func _spawn_spike() -> void:
	var o := Obstacle.new()
	o.kind = "spike"
	o.position = Vector2(spawn_x + 120.0, GROUND_Y - 26.0)
	o.set_meta("scroller", true)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48.0, 52.0)
	shape.shape = rect
	o.add_child(shape)
	o.hit_shape = shape
	var vis := _make_spike(24.0, 52.0)
	vis.position = Vector2(0.0, 0.0)
	o.add_child(vis)
	o.body_vis = vis
	world.add_child(o)


func _spawn_drone() -> void:
	var o := Obstacle.new()
	o.kind = "drone"
	o.position = Vector2(spawn_x + 120.0, GROUND_Y - 104.0)
	o.set_meta("scroller", true)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60.0, 36.0)
	shape.shape = rect
	o.add_child(shape)
	o.hit_shape = shape
	var vis := _make_drone()
	o.add_child(vis)
	o.body_vis = vis
	world.add_child(o)


func _spawn_coin_line(count: int, y_offset: float = -150.0) -> void:
	for i in count:
		var p := Pickup.new()
		p.position = Vector2(spawn_x + 120.0 + i * 46.0, GROUND_Y + y_offset)
		p.set_meta("scroller", true)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40.0, 44.0)
		shape.shape = rect
		p.add_child(shape)
		var vis := _make_coin()
		p.add_child(vis)
		p.coin = vis
		world.add_child(p)
		p.collected.connect(_on_pickup_taken)


func _on_pickup_taken(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	coins += 1
	shake = maxf(shake, 2.0)
	_update_hud()


func _on_player_hit() -> void:
	if dead:
		return
	dead = true
	running = false
	player.set_flash()
	shake = 6.0
	flash_rect.color = Palette.with_alpha(Palette.DANGER, 0.35)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.12)
	var m := int(distance)
	if m > best:
		best = m
		var cfg := ConfigFile.new()
		cfg.set_value("run", "best", best)
		cfg.save("user://neondash.cfg")
	go_score.text = "MESAFE  %d m" % m
	go_coins.text = "COIN  %d" % coins
	go_best.text = "EN İYİ  %d m" % best
	gameover_panel.visible = true
	best_label.text = "EN İYİ  %d m" % best


func _update_hud() -> void:
	distance_label.text = "%d m" % int(distance)
	coin_label.text = "●  %d" % coins


func _setup_input() -> void:
	_bind("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_bind("duck", [KEY_S, KEY_DOWN])
	_bind("pause", [KEY_P])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := event is InputEventKey and event.is_pressed() and not event.is_echo()
	var clicked := event is InputEventMouseButton and event.is_pressed()
	if not pressed and not clicked:
		return
	if title_panel.visible:
		_start_run()
		get_viewport().set_input_as_handled()
	elif gameover_panel.visible:
		_restart()


func _start_run() -> void:
	title_panel.visible = false
	gameover_panel.visible = false
	running = true
	dead = false


func _restart() -> void:
	for child in world.get_children():
		if child != player:
			child.queue_free()
	player.alive = true
	player.rotation = 0.0
	player.sprite.scale = Vector2.ONE
	player.position = Vector2(300.0, GROUND_Y - 40.0)
	player.hitbox.set_deferred("monitoring", true)
	distance = 0.0
	coins = 0
	speed = 520.0
	speed_target = 520.0
	next_spawn = 900.0
	dead = false
	running = true


func _draw() -> void:
	# City skyline (mid layer)
	var x := -skyline_offset
	var i := 0
	while x < VIEW_W + 200.0:
		var s := _skyline_seed(i)
		var w := 60.0 + s * 70.0
		var h := 90.0 + s * 150.0
		draw_rect(Rect2(x, GROUND_Y - h, w, h), Palette.MID)
		# window rows
		var wy := GROUND_Y - h + 18.0
		while wy < GROUND_Y - 20.0:
			var wx := x + 12.0
			while wx < x + w - 14.0:
				if fmod(wx * 3.1 + wy * 7.7 + s * 31.0, 5.0) < 1.6:
					var col := Palette.with_alpha(Palette.ACCENT, 0.35)
					if fmod(wx + wy, 7.0) < 1.0:
						col = Palette.with_alpha(Palette.PRIMARY, 0.28)
					draw_rect(Rect2(wx, wy, 7.0, 10.0), col)
				wx += 22.0
			wy += 26.0
		x += w + 26.0
		i += 1

	# Ground band
	draw_rect(Rect2(0.0, GROUND_Y, VIEW_W, BAND_H), Palette.SURFACE)
	draw_rect(Rect2(0.0, GROUND_Y, VIEW_W, 6.0), Palette.PRIMARY)
	# scrolling stripes
	var o1 := fmod(skyline_offset * 1.0, 90.0)
	var lx := -o1
	while lx < VIEW_W + 100.0:
		draw_rect(Rect2(lx, GROUND_Y + 22.0, 46.0, 5.0), Palette.with_alpha(Palette.PRIMARY, 0.18))
		lx += 90.0
	var o2 := fmod(skyline_offset * 1.6, 150.0)
	var lx2 := -o2
	while lx2 < VIEW_W + 160.0:
		draw_rect(Rect2(lx2, GROUND_Y + 70.0, 80.0, 4.0), Palette.with_alpha(Palette.PRIMARY, 0.10))
		lx2 += 150.0
	draw_rect(Rect2(0.0, GROUND_Y + 132.0, VIEW_W, 4.0), Palette.with_alpha(Palette.PRIMARY, 0.07))


func _skyline_seed(i: int) -> float:
	return fmod(sin(float(i * 37 + skyline_seed) * 12.9898) * 43758.5453, 1.0) * 0.5 + 0.25


func _make_spike(w: float, h: float) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		Vector2(-w, h * 0.5), Vector2(0.0, -h * 0.5), Vector2(w, h * 0.5)
	])
	p.color = Palette.DANGER
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(-w + 4.0, h * 0.5 + 6.0), Vector2(0.0, -h * 0.5 + 8.0), Vector2(w + 8.0, h * 0.5 + 6.0)
	])
	shadow.color = Palette.with_alpha(Palette.OUTLINE, 0.55)
	shadow.z_index = -1
	p.add_child(shadow)
	return p


func _make_drone() -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		Vector2(-32.0, -14.0), Vector2(32.0, -14.0), Vector2(22.0, 16.0), Vector2(-22.0, 16.0)
	])
	p.color = Palette.DANGER
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-20.0, -6.0), Vector2(20.0, -6.0), Vector2(14.0, 6.0), Vector2(-14.0, 6.0)
	])
	glow.color = Palette.ACCENT
	glow.z_index = 1
	p.add_child(glow)
	var fin := Polygon2D.new()
	fin.polygon = PackedVector2Array([Vector2(0.0, -14.0), Vector2(0.0, -34.0)])
	fin.color = Palette.with_alpha(Palette.DANGER, 0.8)
	fin.z_index = -1
	p.add_child(fin)
	return p


func _make_coin() -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		pts.append(Vector2(cos(a) * 16.0, sin(a) * 16.0))
	p.polygon = pts
	p.color = Palette.ACCENT
	var ring := Polygon2D.new()
	var rpts := PackedVector2Array()
	for i in 10:
		var a2 := TAU * i / 10.0
		rpts.append(Vector2(cos(a2) * 20.0, sin(a2) * 20.0))
	ring.polygon = rpts
	ring.color = Palette.with_alpha(Palette.ACCENT, 0.35)
	ring.z_index = -1
	p.add_child(ring)
	return p
