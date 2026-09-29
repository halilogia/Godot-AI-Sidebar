# Characters without art assets

When the game has people or creatures (RPG, fighter, platformer hero, enemies), draw each one as a small figure built from primitives instead of a single circle or triangle. Flat shapes read as placeholders; a figure with a head, body, limbs and one prop reads as a character. This is the difference between the best and the average generated game.

## Recipe (2D, in `_draw()` of one script per character kind)

1. **One `_draw_<kind>()` per silhouette** (`_draw_knight`, `_draw_beast`, `_draw_slime`). Pick the silhouette from a data field (`stats.silhouette`), so a new enemy is data plus, at most, one new draw function.
2. **Layers back to front:** cape or tail, legs and boots, torso, shoulder plates, head, headgear, arms, weapon. Use `draw_colored_polygon` for torso / cape / horns, `draw_rect` for legs and belts, `draw_circle` for head and joints, `draw_line` with width for arms and blades.
3. **Three tones from one colour:** `body`, `body.darkened(0.4)` for the far side and legs, `body.lightened(0.1..0.18)` for the lit side and helmet. Add one accent colour (belt, plume, eyes) that ties the figure to the palette.
4. **A soft shadow under the feet:** `draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.34))`, then `draw_circle` with black at alpha 0.35, then reset the transform.
5. **Scale everything by one `s` factor** so a boss and a minion share the same code.
6. **Animate through offsets, not new art:** idle bob (`sin(time)` on Y), lean into an attack, lunge toward the target, shake when hit, tint flash (`modulate` towards white/red for a moment), sink and fade on death. Call `queue_redraw()` from `_process` while an animation runs.
7. **State shows on the figure:** a defending pose draws an arc shield, low health tints it, a selected target gets a ring.

## Around the figures

- A **backdrop in its own script** (`arena_backdrop.gd`): sky gradient, moon or sun, 2-3 silhouette layers (hills, cave rocks, city blocks) in slightly different tones, a lighter top edge on the ground.
- **Warm light sources** (torches, lamps): a few concentric `draw_circle` rings with falling alpha, so they glow.
- **UI panels** semi-transparent with a thin lighter border, so the scene shows through (see `ui-theme.md`).

## Checks

- Every character kind has its own silhouette; player and enemy differ in colour temperature (cool hero, warm danger).
- One script per character kind plus one backdrop script, not one giant scene script.
- Look at the runtime screenshot: can you tell what each figure is without reading its name?
