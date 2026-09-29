# Top-down shooter / arena

Neon and glow do most of the work here, but only if the arena has structure and the bullets are the brightest things on screen.

## Arena

- The arena fills the window (a thin border of 24-40 px), not a small box in the middle. Floor: two-tone tiles or a faint grid (line alpha 0.06) with a slightly lighter centre; a border wall drawn as a thick line in the accent colour with a soft glow (a second, wider, low-alpha line under it).
- Obstacles (pillars, walls) in a mid-tone with a lighter top edge and a soft shadow offset (4, 6); they also give cover, so add 4-8 of them, symmetrical or seeded-random.
- Add a subtle vignette (dark corners) and a very slow moving background particle layer (dust, 20-40 dots at alpha 0.1) so the empty floor is never dead.

## Player, bullets, enemies

- Player: a bright ship or body (accent colour) with a facing indicator (a nose, a gun barrel), a soft glow ring (`draw_circle` alpha 0.15, radius 1.6x), and an engine or movement trail (a `GPUParticles2D`/`CPUParticles2D` behind it while moving).
- Aiming: a thin line or reticle at the mouse; the gun turns toward it smoothly.
- Bullets: the brightest thing on screen (near white with an accent core), elongated along their direction, a 4-point trail, `z_index` above enemies. Enemy bullets in the danger hue and visibly slower.
- Enemies: one danger hue family, type by shape and size (chaser = small triangle, shooter = diamond, brute = big square with a health ring). Spawn with a 0.4 s warning (a fading ring on the floor), never on top of the player.

## Feedback (this is the whole "feel")

- Muzzle flash (2 short particles + a light flash), casing or spark particles.
- Hit: enemy flashes white for 60 ms, knocks back 6 px, a `burst` of 6-10 particles in its colour; kill: bigger burst + a shockwave ring + score popup.
- Player hit: red vignette pulse, shake under 8 px for 0.15 s, brief invulnerability blink (alpha 0.4 at 12 Hz).
- Screen shake scales with damage; slow-motion is not needed.

## HUD

- Health as segments or a bar in the bottom-left corner, score top centre (large, tabular), wave / combo top-right; a wave banner (`WAVE 3`) slides in for 1 s and disappears.
- Game over: fade to 60% dark, a centred panel with score, best score chip and a Restart button that has focus.

## Checks on the runtime screenshot

- [ ] The arena fills the window, has a visible border and obstacles; the floor has a pattern.
- [ ] Bullets stand out from everything else; the player is easy to find in a crowd.
- [ ] Shoot with `send_input`: flashes, hits and death bursts are visible; `get_runtime_errors` is clean.
- [ ] HUD is in corners and never covers the arena centre.
