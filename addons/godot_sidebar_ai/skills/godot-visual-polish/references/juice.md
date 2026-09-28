# Feedback ("juice"): make actions feel real

Cheap effects, each under 150 ms unless noted. Put them in one `Fx.gd` helper so every game system calls the same functions.

```gdscript
class_name Fx

## White flash on a hit (CanvasItem). Works for Sprite2D, Polygon2D, ColorRect, Control.
static func flash(node: CanvasItem, color := Color(2, 2, 2), time := 0.1) -> void:
	var tw := node.create_tween()
	node.modulate = color
	tw.tween_property(node, "modulate", Color.WHITE, time)

## Scale punch (pickup, button press, placement).
static func punch(node: Node2D, amount := 1.25, time := 0.15) -> void:
	var base := node.scale
	var tw := node.create_tween()
	tw.tween_property(node, "scale", base * amount, time * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base, time * 0.6)

## Camera shake: call on a Camera2D; offset returns to zero.
static func shake(cam: Camera2D, strength := 6.0, time := 0.2) -> void:
	var tw := cam.create_tween()
	for i in 6:
		tw.tween_property(cam, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), time / 7.0)
	tw.tween_property(cam, "offset", Vector2.ZERO, time / 7.0)

## Floating number/text that rises and fades (damage, score, "+1").
static func popup(parent: Node, pos: Vector2, text: String, color := Color("ffd35a")) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.z_index = 100
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("101018"))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 40.0, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)

## One-shot particle burst; frees itself. CPUParticles2D needs no textures and works in every renderer.
static func burst(parent: Node, pos: Vector2, color := Color("ffd35a"), amount := 14, speed := 160.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	parent.add_child(p)
	p.finished.connect(p.queue_free)
```

## Where to use them

- Player or enemy takes damage: `flash`, `popup` with the number, `burst` in the enemy colour; on the player also `shake` (strength 4-8).
- Enemy dies: `burst` (amount 20-30), fade out with a tween, a small `shake`.
- Pickup: `punch` the HUD counter, `popup("+1")`, `burst` in the pickup colour.
- Button/tower placement: `punch` the new node (scale 0 to 1 with `TRANS_BACK`), a ring that expands and fades.
- Projectiles: a short `Line2D` trail (8-10 points, width 3, width curve or fading colour) or small trailing particles.
- Game over/win: dim the field (`ColorRect` with alpha tween to 0.6) and slide a panel in, never a hard cut.

## Limits

Keep particle `amount` under ~40 per burst and free every effect node when done. Do not add continuous emitters to idle scenes. Screen shake never on every frame; only on events.
