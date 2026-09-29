# Tower defense

The screen has to answer four questions instantly: where do enemies walk, where can I build, what did I build, and how am I doing. Colour separation and clear shapes do most of the work.

## Map

- Show the whole map, about 75% of the window height; HUD on top and a build bar at the bottom.
- **Path:** draw it as a thick `Line2D` (width = 0.8 of a tile) in a warm sand or dark stone tone, with a slightly wider darker `Line2D` under it as an edge. Add a subtle inner line or dashed marks along it. Start portal (red glow) and base (teal glow) at the two ends.
- **Buildable ground:** a checkerboard of two close tones (`Color(0.16, 0.26, 0.2)` and `Color(0.18, 0.29, 0.22)`), rounded 4 px inside each cell; decorations (rocks, bushes) only on non-buildable cells so the player learns where not to click.
- The cell under the mouse gets a **placement preview**: a translucent copy of the selected tower plus a range circle (`draw_arc`, alpha 0.25, a fill of alpha 0.08); red when the cell is invalid or unaffordable.

## Towers

- Distinct silhouette AND colour per type: a round cannon (orange), a square frost tower (icy blue) with a snowflake mark, a triangular sniper (green). Base plate under every tower (a darker rounded square) so they sit in the grid.
- The turret rotates toward its target; the barrel recoils 4 px when firing; a muzzle flash for 0.05 s.
- Level-up shows small pips under the tower and a brighter ring.
- Projectiles: bright, small, with a 5-point `Line2D` trail fading out; splash = expanding ring; frost = blue mist that slows.

## Enemies

- One danger hue family (red, magenta, orange); type is shown by shape and size (fast = small diamond, tank = big hex, flyer = winged triangle with a shadow offset far below).
- A health bar above each: 24x4 px, dark backing, green to red by ratio, hidden at full health.
- Walk animation: a 2-3 px bob and a tiny rotation wobble; death = a `burst` of 8 particles and a coin popup.

## HUD

- Top bar: gold (coin icon), lives (heart), wave `3 / 10`, on one themed panel. A big "WAVE 3" banner slides in for 1 s.
- Bottom bar: tower buttons with the icon, name, cost and hotkey (1-3); unaffordable ones dimmed; the selected one outlined. A `Start wave` button is the one primary button and pulses while no wave is running.
- Selected tower panel: name, level, damage, range, sell / upgrade buttons (upgrade shows the cost).

## Feedback

- Lose a life: the base flashes red, the screen shakes 6 px, a heart pops. Wave clear: gold shower + short banner. Game over: fade-in panel with the wave reached and a restart button.
- Never leave particle emitters running on a static screen.

## Checks on the runtime screenshot

- [ ] The path is unmistakable and contrasts with the buildable cells.
- [ ] Each tower type reads at a glance; a preview follows the mouse (move it with `send_input`).
- [ ] Enemies have health bars; HUD shows gold, lives, wave; build bar shows costs.
- [ ] After the first tower is built and a wave starts, projectiles and hits are visible and nothing errors.
