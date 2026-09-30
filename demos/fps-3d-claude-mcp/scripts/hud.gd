class_name Hud
extends CanvasLayer
## Sade, yarı şeffaf savaş arayüzü: alt solda can ve stamina, alt sağda mermi, üstte pusula, ortada nişangâh.

const INK := Color(0.93, 0.92, 0.85)
const SHADOW := Color(0, 0, 0, 0.6)
const HP_COLOR := Color(0.78, 0.2, 0.18)
const STAMINA_COLOR := Color(0.85, 0.75, 0.32)

var player: Player
var hp := 100.0
var max_hp := 100.0
var stamina := 100.0
var max_stamina := 100.0
var clip := 0
var reserve := 0
var weapon_name := ""
var reload_total := 0.0
var damage_flash := 0.0
var hit_flash := 0.0
var kill_flash := false
var dead := false
var overlay: Overlay

class Overlay extends Control:
	var hud: Hud

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var size_v := get_viewport_rect().size
		var font := ThemeDB.fallback_font
		# hasar kızarması
		if hud.damage_flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.7, 0.05, 0.05, hud.damage_flash * 0.35))
		if hud.hp < 30.0 and not hud.dead:
			draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.6, 0.0, 0.0, 0.12 + 0.05 * sin(Time.get_ticks_msec() * 0.008)))
		_draw_compass(size_v, font)
		_draw_crosshair(size_v)
		_draw_bars(size_v, font)
		_draw_ammo(size_v, font)
		if hud.dead:
			draw_rect(Rect2(Vector2.ZERO, size_v), Color(0, 0, 0, 0.55))
			_text(font, "ÖLDÜN", size_v * 0.5 - Vector2(90, 0), 56, Color(0.85, 0.2, 0.18))

	func _text(font: Font, text: String, pos: Vector2, fsize: int, color: Color) -> void:
		draw_string(font, pos + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, SHADOW)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, color)

	func _draw_compass(size_v: Vector2, font: Font) -> void:
		if hud.player == null:
			return
		var heading := fposmod(-rad_to_deg(hud.player.rotation.y), 360.0)
		var cx := size_v.x * 0.5
		var width := 620.0
		var y := 46.0
		draw_line(Vector2(cx - width * 0.5, y), Vector2(cx + width * 0.5, y), Color(1, 1, 1, 0.25), 1.0)
		for deg in range(0, 360, 5):
			var rel := wrapf(float(deg) - heading + 180.0, 0.0, 360.0) - 180.0
			if absf(rel) > 60.0:
				continue
			var x := cx + rel / 60.0 * width * 0.5
			var major := deg % 45 == 0
			var alpha := 1.0 - absf(rel) / 60.0
			draw_line(Vector2(x, y), Vector2(x, y - (12.0 if major else 6.0)), Color(INK.r, INK.g, INK.b, alpha * 0.9), 1.5)
			if major:
				var label := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}[deg] as String
				_text(font, label, Vector2(x - 8.0, y + 22.0), 16, Color(INK.r, INK.g, INK.b, alpha))
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 6, y - 18), Vector2(cx + 6, y - 18), Vector2(cx, y - 8)]), Color(0.9, 0.3, 0.2))
		_text(font, "%03d" % int(heading), Vector2(cx - 16.0, y - 24.0), 15, INK)

	func _draw_crosshair(size_v: Vector2) -> void:
		var c := size_v * 0.5
		var aim := hud.player != null and hud.player.aiming
		var gap := 4.0 if aim else 9.0
		var col := Color(1, 1, 1, 0.85)
		if hud.hit_flash > 0.0:
			col = Color(1.0, 0.25, 0.2, 1.0) if hud.kill_flash else Color(1.0, 0.85, 0.3, 1.0)
			gap += 5.0
		draw_line(c + Vector2(gap, 0), c + Vector2(gap + 8, 0), col, 2.0)
		draw_line(c - Vector2(gap, 0), c - Vector2(gap + 8, 0), col, 2.0)
		draw_line(c + Vector2(0, gap), c + Vector2(0, gap + 8), col, 2.0)
		draw_line(c - Vector2(0, gap), c - Vector2(0, gap + 8), col, 2.0)
		draw_circle(c, 1.5, col)

	func _bar(pos: Vector2, size_v: Vector2, ratio: float, color: Color) -> void:
		draw_rect(Rect2(pos, size_v), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(pos, Vector2(size_v.x * clampf(ratio, 0.0, 1.0), size_v.y)), color)
		draw_rect(Rect2(pos, size_v), Color(1, 1, 1, 0.25), false, 1.0)

	func _draw_bars(size_v: Vector2, font: Font) -> void:
		var base := Vector2(48.0, size_v.y - 86.0)
		_text(font, "CAN  %d" % int(ceil(hud.hp)), base + Vector2(0, -8), 16, INK)
		_bar(base, Vector2(280, 10), hud.hp / hud.max_hp, HP_COLOR)
		var s_col := Color(0.55, 0.5, 0.3) if hud.stamina < 25.0 else STAMINA_COLOR
		_text(font, "NEFES", base + Vector2(0, 34), 14, Color(INK.r, INK.g, INK.b, 0.8))
		_bar(base + Vector2(0, 42), Vector2(280, 6), hud.stamina / hud.max_stamina, s_col)

	func _draw_ammo(size_v: Vector2, font: Font) -> void:
		var pos := Vector2(size_v.x - 240.0, size_v.y - 70.0)
		var low := hud.clip <= 2 and hud.reload_total <= 0.0
		_text(font, "%d" % hud.clip, pos, 54, Color(0.95, 0.3, 0.25) if low else INK)
		_text(font, "/ %d" % hud.reserve, pos + Vector2(84, 0), 26, Color(INK.r, INK.g, INK.b, 0.75))
		_text(font, hud.weapon_name, pos + Vector2(0, 30), 18, Color(0.55, 0.85, 0.75))
		if hud.reload_total > 0.0:
			_text(font, "ŞARJÖR DEĞİŞİYOR", pos + Vector2(-40, -40), 16, Color(0.95, 0.85, 0.4))

func _ready() -> void:
	overlay = Overlay.new()
	overlay.hud = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

func bind(p: Player) -> void:
	player = p
	p.health_changed.connect(func(h: float, m: float) -> void:
		hp = h
		max_hp = m)
	p.stamina_changed.connect(func(v: float, m: float) -> void:
		stamina = v
		max_stamina = m)
	p.ammo_changed.connect(func(c: int, r: int, n: String) -> void:
		clip = c
		reserve = r
		weapon_name = n)
	p.reload_started.connect(func(t: float) -> void: reload_total = t)
	p.damaged.connect(func() -> void: damage_flash = 1.0)
	p.hit_confirmed.connect(func(killed: bool) -> void:
		hit_flash = 0.18
		kill_flash = killed)
	p.died.connect(func() -> void: dead = true)
	p.respawned.connect(func() -> void: dead = false)
	p._emit_all()   # init sırası: HUD bağlandıktan sonra güncel değerleri al

func _process(delta: float) -> void:
	damage_flash = maxf(0.0, damage_flash - delta * 1.6)
	hit_flash = maxf(0.0, hit_flash - delta)
	if reload_total > 0.0 and player != null and player.reload_left <= 0.0:
		reload_total = 0.0
