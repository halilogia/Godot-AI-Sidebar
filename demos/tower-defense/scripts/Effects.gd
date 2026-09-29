class_name Effects
extends Node2D

var _floaters: Array = []

func spawn_float_text(pos: Vector2, text: String, color: Color) -> void:
	_floaters.append({"pos": pos, "text": text, "color": color, "t": 0.0})

func spawn_burst(pos: Vector2, color: Color, amount: int = 8) -> void:
	for i in amount:
		_floaters.append({
			"pos": pos,
			"text": "",
			"color": color,
			"t": 0.0,
			"part": true,
			"vel": Vector2.from_angle(TAU * i / amount + randf()) * randf_range(60.0, 150.0),
		})

func _process(delta: float) -> void:
	var keep: Array = []
	for f in _floaters:
		f["t"] = f["t"] + delta
		if f.get("part", false):
			f["pos"] = f["pos"] + f["vel"] * delta
			f["vel"] *= 0.9
		keep.append(f)
	_floaters = keep
	queue_redraw()

func _draw() -> void:
	for f in _floaters:
		var t: float = f["t"]
		if f.get("part", false):
			if t > 0.45:
				continue
			var a: float = 1.0 - t / 0.45
			draw_circle(f["pos"], 3.5 * a + 1.0, Color(f["color"].r, f["color"].g, f["color"].b, a))
		else:
			if t > 0.9:
				continue
			var a2: float = 1.0 - t / 0.9
			var y: float = f["pos"].y - 34.0 * ease(t / 0.9, 0.3)
			draw_string(ThemeDB.fallback_font, f["pos"] + Vector2(-8, y), f["text"],
				HORIZONTAL_ALIGNMENT_CENTER, 40, 16,
				Color(f["color"].r, f["color"].g, f["color"].b, a2))
