# Grand strategy / map game

Strategy screens fail on **readability**: province names and army numbers vanish on similar-coloured tiles, every region has the same weight, and nothing tells you what is selected. The fixes are mostly about text and outlines, not art.

## Map

- **Shape:** a hex grid or irregular polygons. A hex grid is fastest to generate and looks intentional: axial coordinates `(q, r)` to pixels (pointy-top): `x = size * sqrt(3) * (q + r / 2)`, `y = size * 1.5 * r`. Corners at angles `60 * i - 30` degrees.
- Fit the map to about 70% of the window height with a fixed margin; the sidebar takes the right 22%, the top bar 8%. Compute `size` from those, never guess.
- **Colours:** owners get colours from ONE harmonious set (4-6 desaturated hues, e.g. teal, ochre, brick, violet, moss), neutral land is a muted grey-brown, the sea is darker than every land colour. Variation inside a country: `color.lightened(rng.randf_range(-0.05, 0.08))` per province, so borders read without heavy lines.
- **Borders:** draw each province polygon's outline in `owner_color.darkened(0.45)`, width 1.5; where two different owners touch, use width 3 and a near-black. The selected province: outline in near-white, width 4, drawn last; hovered: a 2 px lighter outline.
- Terrain hint: a tiny procedural mark per province (three short lines for hills, a dot cluster for forest), low alpha, no more than one mark type per province.

## Text that stays readable

Compute the label colour from the tile colour instead of choosing one:
```gdscript
static func label_color_for(bg: Color) -> Color:
	var lum := 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b
	return Color(0.08, 0.08, 0.1) if lum > 0.5 else Color(0.96, 0.96, 0.92)
```
- Always add an outline (`add_theme_constant_override("outline_size", 3)` with the opposite colour) to labels drawn on the map. A real run put mid-grey names on tan tiles at contrast under 2:1; `audit_runtime_ui` flags this, fix what it lists.
- Province names small (11-13 px) and only when the tile is large enough; army numbers bigger (16-18 px, bold) on a small dark rounded chip in the owner colour.

## Units and markers

- Armies: a small flag or shield shape (polygon) in the owner colour on a dark chip, the strength number beside it. Selected army: a pulsing ring (`scale` 1.0 to 1.15, 0.8 s loop).
- Movement: a dashed `Line2D` from the army to the target province with an arrowhead; battle: a short flash + a crossed-swords glyph made of two lines.
- Capital / city: a star or a small tower polygon on the province.

## Layout and panels

- Top bar: date (`Jan 1936`), speed buttons (pause, 1x, 2x, 3x), resources with tiny icons (draw them: coin circle, helmet, gear), all on one themed panel.
- Right side panel: selected province name, owner, population / income / garrison as label-value rows, an action button at the bottom (Recruit, Build). Use the project Theme (`references/ui-theme.md`).
- A bottom event log strip: the last message in the accent colour.
- Keyboard and mouse: click select, right-click move / attack, wheel zoom, drag to pan, space to pause.

## Feel

- Ownership change: the province colour cross-fades over 0.4 s and a ring expands from the centre.
- Turn / day tick: the date label punches; income numbers float up from the top bar.
- Battle result popup: a small panel with both sides' losses; never a blocking modal for routine events.

## Checks on the runtime screenshot

- [ ] Every province label has at least 4.5:1 contrast with its tile (or an outline); no unreadable name.
- [ ] The selected province is obvious at a glance.
- [ ] Borders between owners are visible without zooming; the sea is clearly separate from the land.
- [ ] The map, top bar and side panel do not overlap each other.
