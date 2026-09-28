# Art Direction — Snake

Mood: **neon dusk** (deep blue-black garden, glowing snake).

## Palette (5 colours, use tints/shades only)
- `BG_DEEP`    #0A0E14  window background
- `SURFACE`    #141B26  board surface / panels
- `PRIMARY`    #4ADE80  snake (head bright → tail dark green)
- `ACCENT`     #FBBF24  food + score highlights
- `DANGER`     #F04438  walls, game over, crash flash

## Layout
- Window 1280x720, stretch `canvas_items`, aspect `expand`.
- Board 24x16 cells @ 32px = 768x512, centered horizontally, top at y=140.
- HUD bar occupies y 0..128 — never overlaps the board.
- Play field fills the shorter side comfortably.

## UI
- Rounded panels (radius 14), 1px `SURFACE`-light border, no default grey theme.
- Title 40, HUD values 26, body/hint 18. Text always has a dark outline/shadow.
- Custom Theme built in `Hud.gd`; all colours come from `Palette.gd`.

## Effects
- Eat: expanding amber ring + floating `+10`, screen shake ≤ 6px for 0.15s.
- Death: red flash ≤ 150ms + shake.
- No permanent particle loops.
