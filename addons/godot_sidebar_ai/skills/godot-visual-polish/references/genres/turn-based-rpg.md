# Turn-based RPG / tactics (side-view duel or grid battle)

The best generated battle screen in our tests was not a grid of coloured squares: it was a **stage**. Two drawn characters facing each other on a lit ground, a layered backdrop, glowing torches, and thin translucent panels. Aim for that. Read `references/characters.md` for how to draw the figures.

## Two layouts, pick one

- **Side-view duel / party vs party** (recommended, looks best): heroes left, enemies right, standing on one ground line at ~72% of the screen height; status cards at the top corners, a message box top centre, the command panel docked at the bottom.
- **Grid tactics:** the grid fills the centre (~65% of the width), units are large (at least 1.3x a tile's half width), move range translucent blue, attack range translucent red, selected unit ringed, a turn-order strip of portraits along the top.

## Stage backdrop (its own script, `arena_backdrop.gd`, `_draw()`)

1. Vertical gradient sky from `Color(0.06, 0.07, 0.16)` (top) to `Color(0.22, 0.16, 0.3)` (horizon): draw it as 24-40 thin `draw_rect` strips or a `GradientTexture2D`.
2. A moon or sun: `draw_circle` with a lighter disc plus a larger low-alpha halo.
3. Two silhouette layers (cave rocks, hills, ruined towers) as `draw_colored_polygon`, each a darker tone than the sky; the far layer lighter than the near one. Generate the polygon points with a seeded noise: `y = base + sin(x * f1) * a1 + sin(x * f2) * a2`.
4. Ground: a trapezoid with a lighter top edge line and a darker body; scatter small dark ellipses (stones) with `rng`.
5. Torches / lamps at both edges: a small dark base, a flame polygon in orange, and 4 concentric `draw_circle` rings of falling alpha (0.10, 0.07, 0.04, 0.02) as glow. Animate by scaling the flame with `sin(time * 9.0 + seed)`.

## Characters

- One `_draw_<kind>()` per silhouette, three tones from one colour, a soft ellipse shadow, everything scaled by one factor.
- Animation as offsets: idle bob, lunge toward the target on attack (ease out and back over 0.35 s), lean back and shake when hit, red-white `modulate` flash, sink and fade on death, a shield arc while defending.
- Bosses are the same code with a scale factor of 1.4 and a different accent colour.

## Panels and text

- Status card: rounded panel `Color(0.06, 0.06, 0.1, 0.85)`, 2 px border in a lighter tone, name in the faction colour (warm gold for the party, red for enemies), HP bar green, MP bar blue, and the numbers written **inside or right-aligned above** the bar, never over another bar. A real run drew `52 / 52 MP` on top of the bar edge; keep 4 px of padding.
- Command buttons: 4 across at the bottom, number hotkey in the label (`1  ATTACK`), disabled ones dimmed, a one-line description of the hovered command above them.
- Message box: the last 3-4 lines, newest brightest; damage numbers pop over the target (`references/juice.md`).
- Turn banner: "YOUR TURN" / "ENEMY TURN" sliding in for 0.8 s, then gone.

## Battle feel

- Attack: 0.15 s wind-up, lunge, hit flash on the target, damage number, 60 ms hit-stop (`Engine.time_scale = 0.05` for 0.06 s real time is risky; prefer pausing the attacker's tween), shake under 6 px.
- Critical hit: bigger number, yellow, longer flash. Heal: green number and a soft upward particle burst. Victory / defeat: a fade-in banner with a restart hotkey.

## Checks on the runtime screenshot

- [ ] Characters have heads, bodies and props; you can tell hero from monster without reading names.
- [ ] There is a backdrop with at least two silhouette layers and a lit ground, not one flat colour.
- [ ] No text sits on top of another element; every number is readable.
- [ ] The command panel is fully on screen and shows which commands are usable.
