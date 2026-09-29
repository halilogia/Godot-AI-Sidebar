# Platformer (2D side-scroller)

A platformer has to look good while it MOVES. The three things that separate a designed one from a prototype: a layered background that scrolls at different speeds, a player that squashes and stretches, and platforms that are clearly lighter than the background with a bright top edge.

## World layers, back to front

1. **Sky:** a vertical gradient (deep blue `Color(0.07, 0.09, 0.2)` to a dusk horizon `Color(0.35, 0.28, 0.45)`), a moon or sun disc with a soft halo, 40-70 tiny stars (`rng` positions, alpha 0.4-1.0, two of them twinkle).
2. **Far layer** (`ParallaxLayer.motion_scale = Vector2(0.15, 1)`): mountain silhouettes in a tone just lighter than the sky. Generate the polygon with two summed sines:
```gdscript
func mountain_points(width: float, base_y: float, amp: float, seed_v: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x := 0.0
	while x <= width:
		var y := base_y - (sin(x * 0.004 + seed_v) * 0.6 + sin(x * 0.011 + seed_v * 2.3) * 0.4 + 1.0) * amp * 0.5
		pts.append(Vector2(x, y))
		x += 24.0
	pts.append(Vector2(width, base_y + 400.0)); pts.append(Vector2(0.0, base_y + 400.0))
	return pts
```
3. **Mid layer** (`motion_scale 0.4`): closer hills, pine or building silhouettes, a darker tone than layer 2, with a few lit windows or fireflies as low-alpha dots.
4. **Play layer:** saturated, the most contrasting things on screen. Ground: a 4 px lighter top edge and a darker body; platforms the same, but 15-25% lighter than the background so the route reads.
5. **Foreground accent:** a few blurred dark grass blades or vines at the very bottom edge, moving at 1.2x speed (optional, low alpha).

## Player and enemies

- Player: a saturated colour that appears nowhere else, with two eyes that face the movement direction (flip by `scale.x`). Body as a rounded rect (`draw_rect` plus circles at corners, or a `StyleBoxFlat` with `corner_radius`).
- Squash and stretch: on jump take-off `scale = (0.8, 1.25)` back to 1 in 0.15 s; on landing `scale = (1.3, 0.75)` back in 0.12 s; a 6-particle dust puff at the feet.
- Coyote time (0.1 s) and jump buffer (0.1 s) make it feel right; run and idle bob use a 2 px sine.
- Enemies: the danger colour (red-pink) with angry eyes; patrol with a turn-around; a stomp squashes them flat and pops a few particles.
- Spikes: a row of red triangles, all the same size, drawn with `draw_colored_polygon`.

## Pickups and goal

- Coins: yellow disc with a lighter inner ring, slow bob (`sin(t * 3) * 3`) and a slow scale pulse; collecting = a burst of 8 particles + a `+1` popup + the HUD counter punches.
- **HUD counters must show real totals from the start** (`COINS 0 / 13` counted from the level data at `_ready`, never `0 / 0`; a real run printed `COINS: 0 / 0`).
- Goal flag or door with a glow; a small "reached!" banner when touched.

## Camera and HUD

- `Camera2D` with `position_smoothing_enabled = true` (speed 6), a look-ahead of ~80 px in the facing direction, limits set to the level bounds, zoom so that about 1.5-2 screens of platforms are visible.
- HUD small in the corners: hearts or lives top-left, coins top-right, level name top centre fading out after 2 s. Never over the player's path.
- Checkpoints and death: a quick 0.25 s fade, respawn with a little pop; not a blocking dialog.

## Checks on the runtime screenshot

- [ ] Three visible depth layers with different tones; the platforms are clearly readable against them.
- [ ] The player is the most saturated object; the hazard colour is used for hazards only.
- [ ] Jump and land with `send_input`: the scale change is visible, no errors in `get_runtime_errors`.
- [ ] HUD numbers are real, small and in corners.
