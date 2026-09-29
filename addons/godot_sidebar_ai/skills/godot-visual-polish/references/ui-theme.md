# One Theme for the whole UI

Default Godot controls (grey buttons, thin labels) are the strongest "prototype" signal. Build one `Theme` in code and set it on the root `Control` of the UI; every child inherits it. A `CanvasLayer` does not pass a theme down, so set `theme` on the top `Control` inside it.

```gdscript
class_name GameTheme

static func make(pal: Dictionary) -> Theme:
	# pal: {"bg": Color, "surface": Color, "primary": Color, "accent": Color, "text": Color}
	var t := Theme.new()

	var normal := _box(pal["surface"], pal["primary"], 10, 2)
	var hover := _box(pal["surface"].lightened(0.12), pal["accent"], 10, 2)
	var pressed := _box(pal["surface"].darkened(0.2), pal["accent"], 10, 2)
	var disabled := _box(pal["surface"].darkened(0.4), pal["surface"].darkened(0.2), 10, 2)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", pal["text"])
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", pal["text"].darkened(0.5))
	t.set_font_size("font_size", "Button", 20)

	t.set_stylebox("panel", "PanelContainer", _box(pal["surface"], pal["primary"].darkened(0.3), 14, 2))
	t.set_stylebox("panel", "Panel", _box(pal["surface"], pal["primary"].darkened(0.3), 14, 2))

	t.set_color("font_color", "Label", pal["text"])
	t.set_color("font_outline_color", "Label", pal["bg"])
	t.set_constant("outline_size", "Label", 4)
	t.set_font_size("font_size", "Label", 20)

	t.set_stylebox("background", "ProgressBar", _box(pal["bg"].lightened(0.06), pal["bg"], 6, 1))
	t.set_stylebox("fill", "ProgressBar", _box(pal["accent"], pal["accent"], 6, 0))
	return t

static func _box(fill: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border_w)
	s.set_content_margin_all(12)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s
```

Use: `$UI.theme = GameTheme.make(PALETTE)` once, on the UI root.

## Readable text

- Text over the game world (unit names, damage numbers, HUD over the field) needs an **outline in the background colour**: `label.add_theme_color_override("font_outline_color", Color("101018"))` and `add_theme_constant_override("outline_size", 4)`. Never dark text on a dark unit.
- Text on a panel: light text on a dark surface, or dark text on a light surface; contrast at least 4.5:1.
- Sizes: screen title 40-48, HUD numbers 24-28, labels 18-20, hints 16. Do not go under 14.
- Use one or two hierarchy levels by size and colour (`text` vs a dimmed `text.darkened(0.3)`), not by many fonts.
- Align numbers and labels on a grid; give panels 12-16 px padding (`MarginContainer`).
- Buttons in a list: same width (`custom_minimum_size.x`), 8-12 px separation, centred in a `VBoxContainer`/`HBoxContainer`.

## HUD placement

- Top bar: health/lives left, score centre or right, timers right. Bottom: hints or the action bar.
- Bars (health, mana, XP) use `ProgressBar` or a `ColorRect` pair with the theme colours; show the number too.
- Make the HUD semi-transparent (`modulate.a = 0.9`) and never cover the play field's centre.

## HUD text: real Label nodes, not `draw_string`

Build every HUD number and caption from `Label` (or `RichTextLabel`) nodes under a `CanvasLayer` with the project Theme and an outline (`outline_size` 3). Text painted with `draw_string()` in `_draw()` cannot be measured: `audit_runtime_ui` reports 0 nodes and cannot flag low contrast, overflow or overlap, and it does not scale with the Theme. Use `_draw()` only for shapes (bars, compass ticks, crosshair).
