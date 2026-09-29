extends Control
class_name RaceHUD

var race: Race

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if race == null or race.cars.is_empty():
		return
	var sw := size.x
	var player: Car = race.cars[0]
	_panel(Rect2(24, 20, 230, 92))
	_panel(Rect2(276, 20, 210, 92))
	_panel(Rect2(sw - 254, 20, 230, 92))
	_text(Vector2(44, 62), "LAP %d / %d" % [mini(player.lap + 1, Race.LAPS), Race.LAPS], 22)
	_text(Vector2(44, 96), "TUR %d" % (player.lap + 1), 16, Palette.PRIMARY)
	_text(Vector2(296, 70), "P%d" % player.place, 34, Palette.ACCENT)
	_text(Vector2(296, 100), "SIRA", 16)
	_text(Vector2(sw - 234, 70), "%d" % int(player.speed / 6.0), 34, Palette.PRIMARY)
	_text(Vector2(sw - 234, 100), "KM/S", 16)
	var bw := 180.0
	draw_rect(Rect2(sw - 234, 108, bw, 8), Palette.BG, true)
	draw_rect(Rect2(sw - 234, 108, bw * clampf(player.speed / Car.MAX_SPEED, 0.0, 1.0), 8), Palette.ACCENT, true)
	if player.finished:
		_center_text(Vector2(sw * 0.5, 300.0), "FINISH", 64, Palette.ACCENT)
		_center_text(Vector2(sw * 0.5, 350.0), "SONUC: %d / %d   (R ile yeniden basla)" % [player.place, race.cars.size()], 22, Palette.TEXT)
	var y := 146.0
	for c in race.standings:
		var label := "SEN" if c.is_player else "RACI %d" % c.place
		_text(Vector2(24, y), "%d.  %s" % [c.place, label], 16, Palette.TEXT if c.is_player else Palette.TEXT.darkened(0.35))
		y += 24.0

func _panel(r: Rect2) -> void:
	draw_rect(r, Palette.SURFACE, true)
	draw_rect(r, Color(Palette.PRIMARY, 0.25), false, 2.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Palette.PRIMARY, true)

func _text(pos: Vector2, s: String, fsize: int, c: Color = Palette.TEXT) -> void:
	var f := ThemeDB.fallback_font
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 5, Color(0, 0, 0, 0.7))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, c)

func _center_text(center: Vector2, s: String, fsize: int, c: Color = Palette.TEXT) -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var pos := Vector2(center.x - w * 0.5, center.y)
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 6, Color(0, 0, 0, 0.8))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, c)
