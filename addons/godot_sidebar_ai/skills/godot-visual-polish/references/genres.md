# What each genre must show clearly

Read only your genre's section. Each lists the visual problems that made real generated demos look weak, and the fix.

## Tower defense
- The path must contrast with buildable ground (dark path on light grass, or the reverse); buildable cells get a subtle grid/hover highlight; the tile under the mouse gets a placement preview (ghost tower + range circle).
- Enemies: a strong silhouette in a warm/danger colour, a small health bar above each. Towers: distinct shapes per type (round, square, triangle) and a colour per type; projectiles with a short trail.
- Camera shows the whole map (2D: fit the map to ~75% of the window; 3D: orthographic or 50 degree pitch). HUD: money, lives, wave number top; tower buttons in a bottom bar with cost and hotkey.
- Feedback: hit flash, coin popups, a shake when a life is lost.

## Platformer
- Layered background (gradient sky + 2 parallax silhouette layers); ground with a lighter top edge and a darker body; platforms clearly lighter than the background.
- Player a distinct saturated colour with a face/eye so direction reads; squash and stretch on jump/land (`scale` tween); dust `burst` on landing.
- Hazards use the danger colour only; pickups pulse (`punch` loop, slow) so they draw the eye; camera smooth follow with a look-ahead of ~80 px.
- HUD small and in corners; never over the player's path.

## Top-down shooter / arena
- Arena floor with a subtle pattern or two-tone tiles and a visible border; player bright, bullets brighter than enemies, enemies in one danger hue with size showing type.
- Muzzle flash, bullet impact `burst`, enemy death `burst`, small shake on player hit, damage vignette (red flash).
- Health bar in a corner, score top centre; wave banner slides in and out.

## Match-3 / puzzle
- Board fills ~75% of the shorter side, centred, on a rounded darker panel; tiles distinct in both colour AND shape (colour-blind safe); 4-6 px gaps.
- Swap, match and fall are tweened (0.12-0.25 s), matched tiles `punch` then shrink with a `burst`; combo text pops up.
- Score/moves/timer as three clear top blocks; hint text small at the bottom.

## Card game
- Cards are rounded panels with a header colour per type, an icon shape, cost in a corner badge, readable body text (16+); hovering lifts the card (`position.y -20`, scale 1.08, z_index up) and shows a larger preview.
- Hand fanned along an arc at the bottom; play area in the middle; each side's health/mana as bars with numbers. Drag-and-drop with a return tween.
- Table background: a vignetted gradient, not flat colour.

## Turn-based RPG / tactics
- The grid/map fills the window's centre (aim ~65% width); units are large (at least 1.3x a tile's half-width visible) with name plates using outlined text ABOVE the unit, never dark text on the unit body.
- Move range = translucent blue tiles, attack range = translucent red, selected unit ringed; the active turn order shown as a strip of portraits.
- Action menu is a themed panel of buttons docked at the bottom; the log is a small scrolling panel; damage numbers pop up over the target.

## Grand strategy / map game
- Provinces/regions filled with distinct but harmonious colours from a palette (desaturated), borders drawn as darker lines, selected region outlined brightly; sea/background darker than land.
- Labels (names, armies) small, outlined, and only at readable zoom; map fits the window with pan/zoom (mouse wheel, drag).
- A top bar for date/speed/resources and a side panel for the selected region; panels use the Theme.

## Endless runner / arcade
- Strong parallax (3 layers moving at different speeds), a ground line with a bright edge, the runner in a saturated colour; speed lines or dust at high speed.
- Obstacles in the danger colour with consistent shapes; coins pulse; score huge and simple.
- Difficulty ramps visibly (background hue shifts a little as levels pass).

## Racing
- Track edges high contrast against the surface; a clear centre or racing line; the car has a distinct silhouette from above/behind with a soft shadow.
- Speed shown by camera FOV/zoom widening slightly, skid marks or dust particles, speedometer/lap HUD in corners; off-track surface visibly different.

## First person 3D
- Use `references/lighting-3d.md` fully; variety in the level (walls of two tones, props, lit doorways); a simple crosshair (outlined, 4 lines with a gap); HUD minimal and corner-anchored.
- Pickups glow (emission) and bob/rotate slowly; feedback on pickup (screen flash 80 ms + sound cue placeholder comment).

## Snake / grid arcade
- Checkerboard or subtle grid background in two close tones, rounded segments with a lighter head that has eyes, food with a glow and a slow pulse, score top-left with a best-score chip.
- Grid fills the window's shorter side minus HUD; a flash and shake on death, a fade-in game-over panel with a restart button.
