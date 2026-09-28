class_name Effects
extends Node2D
## Short-lived feedback: expanding ring + floating score text.

const RING_TIME := 0.30
const TEXT_TIME := 0.55

var _rings: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	var i := _rings.size() - 1
	while i >= 0:
		_rings[i]["age"] += delta
		if _rings[i]["age"] >= RING_TIME:
			_rings.remove_at(i)
		i -= 1
	i = _texts.size() - 1
	while i >= 0:
		_texts[i]["age"] += delta
		if _texts[i]["age"] >= TEXT_TIME:
			_texts.remove_at(i)
		i -= 1
	queue_redraw()

func spawn_ring(pos: Vector2, color: Color) -> void:
	_rings.append({"pos": pos, "age": 0.0, "color": color})

func spawn_text(pos: Vector2, label: String, color: Color) -> void:
	_texts.append({"pos": pos, "age": 0.0, "label": label, "color": color})

func _draw() -> void:
	for r in _rings:
		var k: float = clampf(r["age"] / RING_TIME, 0.0, 1.0)
		var rad: float = 6.0 + k * 26.0
		var c: Color = r["color"]
		draw_arc(r["pos"], rad, 0, TAU, 32, Color(c, (1.0 - k) * 0.9), 3.0 * (1.0 - k) + 1.0)
	var font: Font = ThemeDB.fallback_font
	for t in _texts:
		var k2: float = clampf(t["age"] / TEXT_TIME, 0.0, 1.0)
		var col: Color = t["color"]
		var p: Vector2 = t["pos"] + Vector2(0, -26.0 * k2)
		var w: float = font.get_string_size(t["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var origin := p - Vector2(w * 0.5, 0)
		draw_string_outline(font, origin, t["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Palette.BG_DEEP)
		draw_string(font, origin, t["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(col, 1.0 - k2 * k2))
