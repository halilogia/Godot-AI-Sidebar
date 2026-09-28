extends Node2D

const MAX_LIVES := 3

var world: Node2D
var player: Player
var spawn := Vector2.ZERO
var coins_label: Label
var lives_label: Label
var message: Label
var shake := 0.0
var _coins := 0
var _lives := MAX_LIVES
var _won := false

func _ready() -> void:
	randomize()
	_build_background()
	world = Node2D.new()
	world.set_script(preload("res://scripts/World.gd"))
	add_child(world)
	player = world.player
	spawn = world.spawn
	player.died.connect(_on_died)
	_build_hud()
	_refresh_hud()
	# pre-placed pickups: attach simple overlap checks below
	set_process(true)

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG_DEEP
	bg.size = Vector2(1280, 720)
	bg.z_index = -100
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var grad := Gradient.new()
	grad.set_color(0, Palette.SURFACE)
	grad.set_color(1, Palette.BG_DEEP)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.size = Vector2(Level.W * Palette.TILE, Level.H * Palette.TILE)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.z_index = -90
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	# distant skyline
	var city := Node2D.new()
	city.z_index = -80
	add_child(city)
	var x := 0
	while x < Level.W * Palette.TILE:
		var h := 120 + (x / 64 * 37) % 180
		var b := ColorRect.new()
		b.color = Color(Palette.BG_DEEP.r, Palette.BG_DEEP.g, Palette.BG_DEEP.b, 0.92)
		b.position = Vector2(x, Level.H * Palette.TILE - 190 - h)
		b.size = Vector2(46, h)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		city.add_child(b)
		var win := ColorRect.new()
		win.color = Color(Palette.PRIMARY.r, Palette.PRIMARY.g, Palette.PRIMARY.b, 0.35)
		win.position = Vector2(x + 10, Level.H * Palette.TILE - 180 - h)
		win.size = Vector2(10, 14)
		win.mouse_filter = Control.MOUSE_FILTER_IGNORE
		city.add_child(win)
		x += 60

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.position = Vector2(16, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	coins_label = _mk_label("COINS 0")
	coins_label.add_theme_color_override("font_color", Palette.ACCENT)
	lives_label = _mk_label("LIVES 3")
	lives_label.add_theme_color_override("font_color", Palette.DANGER)
	row.add_child(coins_label)
	row.add_child(lives_label)
	message = _mk_label("")
	message.add_theme_color_override("font_color", Palette.PRIMARY)
	message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message.position = Vector2(0, 40)
	message.size = Vector2(1280, 60)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.visible = false
	layer.add_child(message)

func _mk_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Palette.BG_DEEP)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.BG_DEEP.r, Palette.BG_DEEP.g, Palette.BG_DEEP.b, 0.85)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	return sb

func _refresh_hud() -> void:
	coins_label.text = "COINS %d" % _coins
	lives_label.text = "LIVES %d" % _lives

func _process(delta: float) -> void:
	_overlaps()
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 20.0)
		var cam := player.camera
		if cam == null:
			return
		cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
		if shake == 0.0:
			cam.offset = Vector2.ZERO

func _overlaps() -> void:
	if player == null or not is_instance_valid(player):
		return
	var pr := Rect2(player.global_position + Vector2(-12, -34), Vector2(24, 34))
	for c in get_tree().get_nodes_in_group("coins"):
		if c is Coin and Rect2(c.global_position - Vector2(12, 12), Vector2(24, 24)).intersects(pr):
			c.queue_free()
			_coins += 1
			_refresh_hud()
			shake = 3.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Walker and not e.alive:
			continue
		if e is Walker and Rect2(e.global_position - Vector2(14, 18), Vector2(28, 26)).intersects(pr):
			_kill()
			return
	for g in get_tree().get_nodes_in_group("goal"):
		if g is Goal and Rect2(g.global_position - Vector2(12, 82), Vector2(68, 86)).intersects(pr):
			if not _won:
				_won = true
				_flash("GOAL! %d COINS - R ile tekrar" % _coins)
	if _lives > 0:
		var floor_y := float((Level.H - 3) * Palette.TILE)
		if player.global_position.x > 120.0 and player.global_position.x < float(Level.W * Palette.TILE) - 120.0:
			floor_y = 10000.0
		if player.global_position.y > floor_y:
			_kill()

func _kill() -> void:
	if player.global_position.y > 1500.0:
		return
	_lives -= 1
	_refresh_hud()
	shake = 8.0
	if _lives <= 0:
		_flash("GAME OVER - R ile yeniden")
		player.set_physics_process(false)
		return
	_flash("HAYALETI KAYBETTIN")
	_respawn()

func _on_died() -> void:
	pass

func _respawn() -> void:
	player.velocity = Vector2.ZERO
	player.global_position = spawn

func _flash(t: String) -> void:
	message.text = t
	message.visible = true
	await get_tree().create_timer(1.6).timeout
	message.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and _lives <= 0:
		get_tree().reload_current_scene()
