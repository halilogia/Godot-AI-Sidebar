class_name UiTheme
extends RefCounted

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(Palette.SURFACE_LIGHT.r, Palette.SURFACE_LIGHT.g, Palette.SURFACE_LIGHT.b, 0.95)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(10)
	panel.border_color = Palette.BORDER
	panel.set_border_width_all(1)
	t.set_stylebox("panel", "PanelContainer", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Palette.SURFACE_LIGHT
	btn.set_corner_radius_all(10)
	btn.set_content_margin_all(10)
	btn.border_color = Palette.BORDER
	btn.set_border_width_all(1)
	var btn_hover := btn.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Palette.SURFACE_LIGHT.lightened(0.12)
	var btn_press := btn.duplicate() as StyleBoxFlat
	btn_press.bg_color = Palette.PRIMARY.darkened(0.25)
	for c in ["Button"]:
		t.set_stylebox("normal", c, btn)
		t.set_stylebox("hover", c, btn_hover)
		t.set_stylebox("pressed", c, btn_press)
		t.set_stylebox("focus", c, btn)
	t.set_color("font_color", "Button", Palette.TEXT)
	t.set_font_size("font_size", "Button", 20)
	t.set_color("font_color", "Label", Palette.TEXT)
	return t
