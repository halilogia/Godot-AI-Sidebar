# Match-3 / falling-block puzzle

Match-3 lives on **tile design and motion**. Colour alone is not enough (colour-blind players, and it looks cheap): every gem type gets its own colour AND its own shape, with a highlight so it reads as a glossy object.

## Board

- The board is a rounded dark panel (`Color(0.1, 0.1, 0.18)`, corner radius 16, 2 px lighter border) centred, covering about 75% of the window's shorter side. Cell size from the viewport: `cell = floor(min(size.x * 0.7 / cols, (size.y - hud_h - hint_h) * 0.85 / rows))`.
- Cells: a slightly lighter checker (`alpha 0.06`) behind the gems so the grid is felt but not loud; 4-6 px gaps between gems.
- Background outside the board: a radial or vertical gradient in the palette with a few large blurred circles at low alpha drifting slowly (parallax feel).

## Gem shapes (draw with `_draw()`, one function per type)

Six types are enough. Each one: base colour, a darker outline (`darkened(0.35)`, width 3), a lighter inner facet, and a small white highlight at the top-left.
- circle (red), diamond (blue, `PackedVector2Array` of 4 points), triangle (green), square with cut corners (yellow), hexagon (purple), star (orange).
```gdscript
func draw_gem(kind: int, r: float) -> void:
	var base: Color = GEM_COLORS[kind]
	var pts := _shape_points(kind, r)                       # polygon around (0, 0)
	draw_colored_polygon(pts, base)
	draw_polyline(pts + PackedVector2Array([pts[0]]), base.darkened(0.35), 3.0)
	draw_colored_polygon(_scale_points(pts, 0.6), base.lightened(0.18))
	draw_circle(Vector2(-r * 0.3, -r * 0.35), r * 0.13, Color(1, 1, 1, 0.75))
```
- Selected gem: scale 1.1 and a pulsing ring; hint (after 5 s idle): the two swappable gems wiggle.

## Motion (tween everything; 0.12-0.25 s)

- Swap: both gems move to each other's cell (0.15 s); an invalid swap moves back with a small shake.
- Match: gems `punch` (scale 1.25) then shrink to 0 with a `burst` of 6-8 small shapes in the gem colour; score popup at the match centre.
- Fall: gravity-style tween with a tiny bounce (`TRANS_BOUNCE` 0.2 s), new gems drop in from above the board (clipped by the panel, or fade in).
- Combos: each chain step raises the popup size and pitch (placeholder comment for sound); a combo of 4+ gets a screen flash of 80 ms and a small shake.
- Special gems (4 or 5 in a row): a glow ring and a distinct overlay (a horizontal / vertical bar, a bomb, a rainbow).

## HUD

- Three clear blocks on top: SCORE (big number, punches on change), MOVES (or TIME with a shrinking bar), GOAL / LEVEL. Below the board: a small hint line and a Restart / Shuffle button.
- End of level: dim the board to 50%, a centred panel with stars (drawn), score and a Next button. Game over likewise.

## Checks on the runtime screenshot

- [ ] Six gem types are distinguishable by shape and by colour in greyscale.
- [ ] The board is centred, fully visible (first and last row/column complete) and does not sit under the HUD.
- [ ] Swap two gems with `send_input` click steps: the swap, match and fall are animated, the score changes.
- [ ] No board deadlock: after every move there is a possible swap, otherwise shuffle.
