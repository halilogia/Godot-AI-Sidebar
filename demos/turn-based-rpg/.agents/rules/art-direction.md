# Art Direction — turn-based-rpg demo

Mood: "taş zindan, meşale ışığı" (warm dungeon torchlight).

Palette (only these 5 + tints/shades):
- Background: #14100F (deep warm black)
- Surface: #2A2220 (stone panel) / #3A302C (raised)
- Primary: #E8D5B0 (parchment text)
- Accent: #F0A830 (torch gold, highlight, player side)
- Danger: #C4453C (blood red, enemy side, damage)

Rules:
- 1280x720, stretch canvas_items, aspect expand.
- Field occupies the middle ~70% of the shorter side; HUD bars sit in a top bar, command menu in a bottom bar — never overlapping the field.
- Text: parchment on stone, font size 32 title, 20-22 HUD, 16 hint. Always with dark outline/shadow.
- UI: custom Theme, rounded corners 8px, hover = lighter surface, pressed = gold tint.
- Background is a vertical gradient + vignette, not flat.
- Effects: hit flash <150ms, shake <6px, floating damage numbers, no idle particle loops.
