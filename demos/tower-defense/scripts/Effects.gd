extends Node2D

var _shots: Array = []
var _banner_text := ""
var _banner_t := 0.0
var _pops: Array = []
var _font: Font = ThemeDB.fallback_font

func shot(a: Vector2, b: Vector2, color: Color) -> void:
	_shots.append({"a": a, "b": b, "t": 0.0, "c": color})

func pop(pos: Vector2, text: String, color: Color) -> void:
	_pops.append({"p": pos, "t": 0.0, "s": text, "c": color})

func banner(text: String) -> void:
	_banner_text = text
	_banner_t = 1.6

func _process(delta: float) -> void:
	for i in range(_shots.size() - 1, -1, -1):
		_shots[i]["t"] = float(_shots[i]["t"]) + delta * 6.0
		if float(_shots[i]["t"]) >= 1.0:
			_shots.remove_at(i)
	for i in range(_pops.size() - 1, -1, -1):
		_pops[i]["t"] = float(_pops[i]["t"]) + delta * 1.1
		if float(_pops[i]["t"]) >= 1.0:
			_pops.remove_at(i)
	_banner_t = maxf(0.0, _banner_t - delta)
	queue_redraw()

func _draw() -> void:
	for s in _shots:
		var p: float = clampf(s["t"], 0.0, 1.0)
		var a: Vector2 = s["a"]
		var b: Vector2 = s["b"]
		var pos: Vector2 = a.lerp(b, p)
		var tail: Vector2 = a.lerp(b, maxf(0.0, p - 0.25))
		draw_line(tail, pos, s["c"], 3.0)
		draw_circle(pos, 4.0, Color.WHITE)
	for q in _pops:
		var t: float = q["t"]
		var p: Vector2 = q["p"] + Vector2(0, -30.0 * t)
		var c: Color = q["c"]
		c.a = 1.0 - t
		draw_string(_font, p + Vector2(1, 1), q["s"], HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(0, 0, 0, 0.6 * c.a))
		draw_string(_font, p, q["s"], HORIZONTAL_ALIGNMENT_CENTER, -1, 18, c)
	if _banner_t > 0.0:
		var a2: float = clampf(_banner_t * 2.0, 0.0, 1.0)
		var vs := get_viewport_rect().size
		var fs := 44
		var w: float = _font.get_string_size(_banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bx: float = vs.x * 0.5 - w * 0.5 - 26.0
		var by: float = 150.0 - (1.6 - _banner_t) * 24.0
		draw_rect(Rect2(bx, by - 46.0, w + 52.0, 64.0), Color(0.05, 0.06, 0.13, 0.8 * a2))
		var bc := Palette.ACCENT
		bc.a = a2
		draw_rect(Rect2(bx, by - 46.0, w + 52.0, 64.0), bc, false, 2.0)
		var tc := Palette.ACCENT
		tc.a = a2
		draw_string(_font, Vector2(bx + 26.0, by), _banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
