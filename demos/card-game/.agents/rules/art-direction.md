# Art Direction — "Guess Higher" card demo

Mood: warm dusk casino table, deep felt green + brass accents, calm and readable.

## Palette (only these + tints/shades)
- Background (far, felt dark): #14261F
- Surface (panel / table): #1E3A30
- Primary (cards, text): #F2E8D5
- Accent (brass gold, highlights, score): #E0A83B
- Danger (lose, wrong guess): #C4553B

## Layout
- Design resolution 1280x720, stretch canvas_items / expand.
- Play field fills the window: table gradient background, card centered.
- Top HUD bar (score / streak / round) never overlaps the card.
- Bottom row: two big guess buttons + restart.

## UI style
- Corner radius 10-14, 2px gold border on panels, brass button with dark text.
- Title 34, HUD 22, body 18. Text on light surfaces uses dark ink #1B2A24.

## Effects
- Subtle: card slide-in tween 0.25s, win flash (gold, 120ms), lose shake (6px, 150ms), no loops.
