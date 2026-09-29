class_name UiFactory
extends RefCounted

## Kod ile tema üretir: panel, buton, yazı stilleri.

static func panel_style(bg: Color, radius: int = 10, border: int = 0, border_color: Color = Palette.PRIMARY) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_color
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func label(text: String, size_px: int, color: Color = Palette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.TEXT_DARK)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_font_override("font", _font())
	return l


static func _font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Inter", "Segoe UI", "DejaVu Sans", "sans-serif"])
	f.font_weight = 700
	return f


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font())
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Palette.TEXT)
	b.add_theme_color_override("font_hover_color", Palette.ACCENT)
	b.add_theme_color_override("font_pressed_color", Palette.PRIMARY)
	var normal := panel_style(Palette.SURFACE, 8, 2, Palette.PRIMARY)
	var hover := panel_style(Palette.SURFACE.lightened(0.12), 8, 2, Palette.ACCENT)
	var pressed := panel_style(Palette.SURFACE.darkened(0.2), 8, 2, Palette.ACCENT)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	return b
