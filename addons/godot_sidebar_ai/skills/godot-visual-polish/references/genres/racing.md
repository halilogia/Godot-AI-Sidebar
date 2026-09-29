# Racing (top-down or behind-the-car)

A racing game needs a track that reads as a track: an edge, a surface, kerbs, a start line, and a car that has a silhouette and a shadow. Speed must be felt (zoom, particles, blur lines), not only shown by a number.

## Top-down track

- Build the racing line as a closed smooth curve (a `Curve2D` with 8-14 control points and `bake_interval = 6`, or a `Path2D`); draw it in layers with `Line2D` from the baked points, all closed:
  1. **Grass / infield:** fill colour (`Color(0.16, 0.3, 0.16)`) with a subtle two-tone stripe pattern.
  2. **Kerbs:** width = track width + 20, alternating red and white segments (draw short polylines in a loop, 30 px each).
  3. **Track edge:** width = track width + 8, a light line (`Color(0.9, 0.9, 0.9)`).
  4. **Asphalt:** width = track width (about 12-14% of the screen height), dark grey `Color(0.2, 0.2, 0.22)`.
  5. **Centre line:** a dashed thin light line; **start / finish line:** a checkered strip across the track (two rows of alternating squares).
- The off-track surface (grass, gravel) must look different and slow the car; add a small dust or grass particle when it is on it.
- Fit the whole track (or a camera that follows with a zoom of 0.8-1.0) to the window; a mini-map in a corner if the camera follows.

## Cars

- A distinct silhouette from above: body (rounded rect with a tapered nose), a lighter windscreen, four dark wheels that steer a little, a soft shadow offset (4, 6), headlight glow ahead at night. Each racer has its own colour; the player is the most saturated and gets a small marker.
- Skid marks: a `Line2D` per rear wheel that fades out when the car drifts; drifting also spawns smoke puffs.
- Boost: a flame trail and the FOV/zoom widening.

## Speed feel

- Zoom out 5-8% at high speed (smooth lerp), speed lines at the edges above 70%, a tiny camera shake on kerbs, engine pitch placeholder comment. Motion blur substitute: a faint trail of 3 fading copies of the car at top speed.

## HUD

- Speedometer (a radial arc with a needle, or a number with a bar) bottom-right, lap `2 / 3` and position `P2` top-left with a large ordinal, lap time and best lap top-centre, a countdown (`3 2 1 GO`) with a scale punch at the start. Wrong-way arrow in red if the car faces backwards.
- Finish: a results table sliding in with positions and times; a Restart focused.

## AI and fairness (visible quality)

- AI cars follow the path with a slight lateral offset each, so they do not stack; they slow in tight corners; rubber-band lightly so the race stays close.

## Checks on the runtime screenshot

- [ ] The track has an edge, kerbs, asphalt, a centre line and a start line; grass is clearly off-track.
- [ ] The car has a silhouette, shadow and steering wheels; opponents have other colours.
- [ ] The lap, position and speed are readable; the whole layout fits at 1280x720.
- [ ] Drive with `send_input` (hold accelerate + steer for 3 s): skid marks or particles appear, the lap counter works, no errors.
