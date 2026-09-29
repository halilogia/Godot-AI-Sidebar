# Endless runner / arcade

The runner's whole look is **parallax and speed**. Three layers at clearly different speeds, a bright ground edge, and effects that grow with speed give a feeling of motion even with simple shapes. (The neon skyline runs in our tests were among the best-looking results.)

## Parallax city (or forest, desert)

Build three layers as repeating strips wider than the screen (wrap `position.x` with `fposmod`) moving at `speed * 0.15`, `0.35`, `0.65`:
1. **Far skyline:** rectangles of random width 40-90 px and height 80-220 px in a tone just above the sky colour; a few windows as tiny lit dots.
2. **Mid skyline:** taller, a bit darker, with more lit windows (alpha 0.6, some flicker) and antennas.
3. **Near silhouettes:** poles, signs, arches; the darkest, moving fastest, sparse.
```gdscript
func make_skyline(width: float, min_h: float, max_h: float, tone: Color) -> Node2D:
	var root := Node2D.new()
	var x := 0.0
	while x < width:
		var w := rng.randf_range(40.0, 90.0)
		var h := rng.randf_range(min_h, max_h)
		var r := ColorRect.new()
		r.color = tone
		r.position = Vector2(x, ground_y - h); r.size = Vector2(w, h)
		root.add_child(r)
		x += w + rng.randf_range(0.0, 14.0)
	return root
```
- Sky: a gradient (dusk purple to orange horizon, or deep navy to teal for neon), a big sun or moon disc with halo, a few stars.
- Ground: a 3 px bright edge line in the accent colour, a darker body with repeating marks that scroll at full speed; a faint reflection of the runner and lights below the edge for neon looks.

## Runner and obstacles

- Runner: a saturated colour, a simple face or visor, a 2-frame or procedural run cycle (legs as two lines swinging with `sin`), squash on landing with a dust puff, a trail of 4 fading copies when speed is high.
- Jump arc feels good with a higher gravity on the way down (1.6x) and a short hold-to-jump-higher window.
- Obstacles: the danger colour in consistent shapes (blocks, spikes, low bars to duck under); flying ones cast a shadow on the ground. Coins in arcs, a slow pulse; collecting shows a small `+1` and a tiny burst.
- Difficulty ramp: speed rises smoothly; every 500 points the sky hue shifts a little and a banner shows the level.

## Speed feedback

- Speed lines (5-10 thin horizontal lines, alpha 0.15, moving fast) that appear above 70% of max speed; the camera zoom widens by 3%; a subtle screen shake on landing only.

## HUD and states

- Score huge and simple (top centre or top-left), best-score chip; distance as a thin progress bar. Start screen: a title with the controls (`SPACE / W to jump`) and "Press any key"; game over: dimmed screen, big score, best score, Restart focused.

## Checks on the runtime screenshot

- [ ] At least three layers with different tones; the ground edge glows or is clearly bright.
- [ ] The runner, obstacles and coins are obviously different in colour and shape.
- [ ] Jump with `send_input`: the runner squashes, dust appears, no errors; collide and check the game-over state and restart.
