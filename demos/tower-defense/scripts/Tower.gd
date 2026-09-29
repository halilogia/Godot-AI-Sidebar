class_name Tower
extends Node2D

signal wants_fire(tower: Tower, target: Node2D)

var kind: TowerData.Kind = TowerData.Kind.ARCHER
var cell := Vector2i.ZERO
var level := 1
var cooldown_left := 0.0
var recoil := 0.0
var muzzle_flash := 0.0
var range_px := 200.0

func _process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	recoil = maxf(0.0, recoil - delta * 5.0)
	muzzle_flash = maxf(0.0, muzzle_flash - delta)
	queue_redraw()

func has_target(enemies: Array) -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for e: Enemy in enemies:
		var d: float = global_position.distance_to(e.global_position)
		if d < range_px and d < best_d:
			best_d = d
			best = e
	return best

func can_upgrade() -> bool:
	return level < 3

func upgrade_cost() -> int:
	return int(TowerData.DEFS[kind]["cost"] * (0.8 * level))

func stats() -> Dictionary:
	var base: Dictionary = TowerData.DEFS[kind]
	var mult: float = 1.0 + 0.55 * (level - 1)
	return {
		"damage": float(base["damage"]) * mult,
		"range": float(base["range"]) * (1.0 + 0.1 * (level - 1)),
		"cooldown": float(base["cooldown"]) / (1.0 + 0.12 * (level - 1)),
		"slow": base["slow"],
	}

func refresh() -> void:
	range_px = float(stats()["range"])

func _draw() -> void:
	var base_color: Color = Palette.SURFACE_LIGHT
	var top_color: Color = Palette.PRIMARY
	match kind:
		TowerData.Kind.ARCHER:
			top_color = Palette.PRIMARY
		TowerData.Kind.CANNON:
			top_color = Palette.ACCENT
		TowerData.Kind.FROST:
			top_color = Palette.FROST

	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 20.0, Palette.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_circle(Vector2.ZERO, 19.0, base_color)
	draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 28, base_color.lightened(0.25), 2.0)

	# range ring while selected is handled by game; keep faint for readability
	draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 64,
		Color(top_color.r, top_color.g, top_color.b, 0.12), 2.0)

	var back := Vector2(0, -recoil * 3.0)
	match kind:
		TowerData.Kind.ARCHER:
			draw_line(back + Vector2(0, -6), back + Vector2(0, 10), top_color.darkened(0.4), 5.0)
			draw_line(back + Vector2(-6, 2), back + Vector2(6, 2), top_color.darkened(0.4), 4.0)
			draw_circle(back + Vector2(0, -10), 6.0, top_color)
		TowerData.Kind.CANNON:
			draw_circle(back + Vector2(0, -4), 12.0, top_color.darkened(0.3))
			draw_circle(back + Vector2(0, -4), 7.0, top_color)
		TowerData.Kind.FROST:
			var pts := PackedVector2Array()
			for i in 6:
				var a := TAU * i / 6.0 - PI * 0.5
				var rad := 13.0 if i % 2 == 0 else 6.0
				pts.append(back + Vector2(cos(a), sin(a)) * rad)
			draw_colored_polygon(pts, top_color)

	for i in level:
		draw_circle(Vector2(-8.0 + i * 8.0, 12.0), 2.5, Palette.ACCENT)

	if muzzle_flash > 0.0:
		draw_circle(back + Vector2(0, -12), 9.0 * muzzle_flash, Color(1, 1, 1, 0.6 * muzzle_flash))
