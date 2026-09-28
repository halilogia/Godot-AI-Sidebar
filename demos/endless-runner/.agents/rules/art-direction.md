# Art direction — Neon Dash (2D endless runner)

Mood: neon night city, readable and high contrast.

- Background (sky, far): #101225
- Mid layer (city silhouette, hills): #1a1f3d
- Surface (ground band, panels): #262c52
- Primary (player, UI, coins highlight): #4ce6b3
- Accent (coins, highlight lines): #ffd166
- Danger (spikes, hit flash): #ef476f

- Design size 1280x720, stretch canvas_items, aspect expand. Ground top at y=540, player at x=300.
- Ground band = 180px tall with a 6px primary top line; 3 scrolling stripe layers for motion depth.
- UI: rounded panels (radius 14), no default grey; title 40, HUD 22, body 16; text always with dark outline.
- Effects: subtle. Hit flash 120 ms, screen shake 6 px max, coin pickup = scale pop + score popup.
- Every object is procedural shapes. No image files.
- All colours come from res://scripts/palette.gd constants.
