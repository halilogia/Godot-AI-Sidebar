# Snake / grid arcade

Snake is simple, so the polish is in the details: a designed board, a snake with a face, food that glows, and a satisfying death. Do not let the board sit as a small square in an empty window.

## Board

- The grid fills the window's shorter side minus the HUD (`cell = floor(min(size.x, size.y - hud_h) * 0.92 / max(cols, rows))`), centred, on a rounded darker panel with a 3 px border in the accent colour at alpha 0.5.
- Checkerboard in two very close tones (`Color(0.09, 0.13, 0.2)` and `Color(0.1, 0.15, 0.23)`) or a faint grid line alpha 0.05; a vignette around the panel; a second layer behind (a large blurred circle or two at low alpha) so the window background is not flat.

## Snake

- Rounded segments (`draw_rect` with corner circles, or `StyleBoxFlat`), each slightly smaller than the cell (85%) so the body shows gaps; colour gradient from the head (bright `Color(0.4, 0.95, 0.6)`) to the tail (darker, `darkened(0.35)`).
- Head: lighter, with two eyes (white circles with dark pupils) that look in the moving direction, a tiny tongue flick every 2 s.
- Movement smoothing: interpolate the segment positions between grid steps (lerp with the tick progress) instead of teleporting cell to cell.
- Growth: the new segment pops in (scale 0 to 1, 0.12 s); eating pulses the whole body once.

## Food and extras

- Food: a red-orange apple or orb with a lighter highlight, a soft glow ring, a slow scale pulse (1.0 to 1.12, 0.9 s), a spawn animation (scale-in) and an eat burst of 6 particles.
- Optional bonus food that shrinks/expires with a thin timer ring; optional walls/obstacles drawn as raised blocks.

## Feedback and HUD

- Score top-left with a punch on change, a `BEST` chip top-right, speed / level small under the score; a subtle shake and a red flash on death, the snake fades segment by segment from the head.
- Game over: dim the board to 50%, a centred panel with the score, best score and a Restart button with focus (Enter/Space also restarts); a pause overlay with P/Esc.
- Controls: arrows and WASD; buffer the next direction so two fast key presses in one tick both count, and forbid a direct reverse.

## Checks on the runtime screenshot

- [ ] The board is centred and large (at least ~80% of the shorter side), with a visible pattern and panel.
- [ ] The snake has a head with eyes and a body gradient; food glows.
- [ ] Steer with `send_input` (arrow keys), eat food: score increases and the segment grows; hit a wall: the death animation and game over panel appear; Restart works.
