@tool
extends RefCounted
class_name AISidebarUIThemeScaffold

## scaffold_ui_theme çekirdeği: tasarım belirteçlerinden (renk, yarıçap, boşluk, yazı ölçeği) Theme üretir.
## Belirteçler tek kaynaktır: Theme da, yanındaki `.tokens.json` da, kontrast raporu da bundan çıkar.

const AISidebarRuntimeUiAudit = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_ui_audit.gd")

const PRESETS: Dictionary = {
	"dark": {
		"primary": "#4f46e5", "secondary": "#06b6d4", "background": "#0f172a", "surface": "#1e293b",
		"surface_hover": "#334155", "text": "#f8fafc", "text_muted": "#94a3b8", "accent": "#f59e0b",
		"danger": "#ef4444", "success": "#22c55e"
	},
	"light": {
		"primary": "#4338ca", "secondary": "#0e7490", "background": "#f8fafc", "surface": "#ffffff",
		"surface_hover": "#e2e8f0", "text": "#0f172a", "text_muted": "#475569", "accent": "#b45309",
		"danger": "#b91c1c", "success": "#15803d"
	},
	"parchment": {
		"primary": "#8a241b", "secondary": "#3e5a6b", "background": "#efe5cc", "surface": "#e6d9bb",
		"surface_hover": "#d9caa8", "text": "#2a2016", "text_muted": "#5c4b35", "accent": "#8c7349",
		"danger": "#8a241b", "success": "#3b5922"
	}
}

## Eski (düz) araç argümanı -> belirteç adı.
const LEGACY_COLOR_ARGS: Dictionary = {
	"primary_color": "primary", "secondary_color": "secondary", "background_color": "background",
	"surface_color": "surface", "surface_hover_color": "surface_hover", "text_color": "text",
	"text_muted_color": "text_muted", "accent_color": "accent", "danger_color": "danger", "success_color": "success"
}

const VARIATIONS: Array[String] = [
	"PrimaryButton", "DangerButton", "GhostButton", "Card", "HeaderLarge", "HeaderMedium", "Caption",
	"AccentLabel", "DangerLabel", "HealthBar", "DangerBar", "AccentBar"
]

## Kontrast çiftleri: [ön plan belirteci, arka plan belirteci, asgari oran].
const CONTRAST_PAIRS: Array = [
	["text", "background", 4.5], ["text", "surface", 4.5], ["text", "surface_hover", 4.5],
	["text_muted", "surface", 3.0], ["on_primary", "primary", 4.5]
]

static func resolve_tokens(args: Dictionary) -> Dictionary:
	var preset: String = str(args.get("preset", "dark")).to_lower()
	if not PRESETS.has(preset):
		preset = "dark"
	var overrides: Dictionary = args.get("tokens", {}) if args.get("tokens") is Dictionary else {}
	var color_over: Dictionary = overrides.get("color", {}) if overrides.get("color") is Dictionary else {}
	var colors: Dictionary = {}
	var preset_colors: Dictionary = PRESETS.get(preset, {}) if PRESETS.get(preset) is Dictionary else {}
	for key: String in preset_colors:
		var hex: String = str(preset_colors[key])
		var legacy_arg: String = ""
		for arg_name: String in LEGACY_COLOR_ARGS:
			if LEGACY_COLOR_ARGS[arg_name] == key:
				legacy_arg = arg_name
		if not legacy_arg.is_empty() and args.has(legacy_arg):
			hex = str(args[legacy_arg])
		if color_over.has(key):
			hex = str(color_over[key])
		colors[key] = Color.from_string(hex, Color.from_string(str(preset_colors[key]), Color.MAGENTA))
	var primary: Color = colors["primary"]
	var on_primary: Color = Color.WHITE if _contrast(Color.WHITE, primary) >= _contrast(Color(0.04, 0.05, 0.09), primary) else Color(0.04, 0.05, 0.09)
	colors["on_primary"] = on_primary
	var radius_over: Dictionary = overrides.get("radius", {}) if overrides.get("radius") is Dictionary else {}
	var rad_md: int = clampi(str(radius_over.get("md", args.get("corner_radius", 8))).to_int(), 0, 32)
	var radius: Dictionary = {
		"sm": clampi(str(radius_over.get("sm", maxi(2, rad_md / 2) if rad_md > 0 else 0)).to_int(), 0, 32),
		"md": rad_md,
		"lg": clampi(str(radius_over.get("lg", rad_md * 2)).to_int(), 0, 48)
	}
	var space_over: Dictionary = overrides.get("spacing", {}) if overrides.get("spacing") is Dictionary else {}
	var unit: int = clampi(str(args.get("spacing_unit", 4)).to_int(), 1, 16)
	var spacing: Dictionary = {}
	var steps: Dictionary = {"xs": 1, "sm": 2, "md": 3, "lg": 4, "xl": 6}
	for key: String in steps:
		var step_mult: int = str(steps[key]).to_int()
		spacing[key] = clampi(str(space_over.get(key, step_mult * unit)).to_int(), 0, 128)
	var font_over: Dictionary = overrides.get("font_size", {}) if overrides.get("font_size") is Dictionary else {}
	var body: int = clampi(str(font_over.get("body", args.get("font_size_body", 16))).to_int(), 8, 72)
	var font_size: Dictionary = {
		"body": body,
		"small": clampi(str(font_over.get("small", args.get("font_size_small", roundi(body * 0.75)))).to_int(), 6, 72),
		"title": clampi(str(font_over.get("title", args.get("font_size_title", roundi(body * 1.375)))).to_int(), 8, 96),
		"heading": clampi(str(font_over.get("heading", roundi(body * 1.75))).to_int(), 8, 128)
	}
	return {
		"preset": preset, "color": colors, "radius": radius, "spacing": spacing, "font_size": font_size,
		"border_width": clampi(str(overrides.get("border_width", 1)).to_int(), 0, 8)
	}

static func tokens_to_json(tokens: Dictionary, token_map: Dictionary = {}) -> Dictionary:
	var out: Dictionary = tokens.duplicate(true)
	var hex: Dictionary = {}
	var col_dict: Dictionary = tokens.get("color", {}) if tokens.get("color") is Dictionary else {}
	for key: String in col_dict:
		var mapped_key: String = str(token_map.get(key, key))
		var col_val: Color = col_dict[key] if col_dict[key] is Color else Color.MAGENTA
		hex[mapped_key] = "#" + col_val.to_html(false)
	out["color"] = hex
	out["colors"] = hex.duplicate()
	out["schema"] = "ui-tokens/1"
	out["variations"] = VARIATIONS
	return out

static func contrast_report(tokens: Dictionary) -> Dictionary:
	var colors: Dictionary = tokens.get("color", {}) if tokens.get("color") is Dictionary else {}
	var checks: Array[Dictionary] = []
	var warnings: Array[String] = []
	for pair: Array in CONTRAST_PAIRS:
		var fg_c: Color = colors.get(pair[0], Color.WHITE) if colors.get(pair[0]) is Color else Color.WHITE
		var bg_c: Color = colors.get(pair[1], Color.BLACK) if colors.get(pair[1]) is Color else Color.BLACK
		var req_min: float = str(pair[2]).to_float()
		var ratio: float = _contrast(fg_c, bg_c)
		var ok: bool = ratio >= req_min
		checks.append({"foreground": pair[0], "background": pair[1], "ratio": snappedf(ratio, 0.01), "minimum": req_min, "passed": ok})
		if not ok:
			warnings.append("Düşük kontrast: '%s' / '%s' = %.2f:1 (asgari %.1f:1)." % [pair[0], pair[1], ratio, req_min])
	return {"checks": checks, "warnings": warnings, "passed": warnings.is_empty()}

static func build_theme(tokens: Dictionary) -> Theme:
	var c: Dictionary = tokens.get("color", {}) if tokens.get("color") is Dictionary else {}
	var r: Dictionary = tokens.get("radius", {}) if tokens.get("radius") is Dictionary else {}
	var sp: Dictionary = tokens.get("spacing", {}) if tokens.get("spacing") is Dictionary else {}
	var fs: Dictionary = tokens.get("font_size", {}) if tokens.get("font_size") is Dictionary else {}
	var bw: int = str(tokens.get("border_width", 1)).to_int()
	var pri: Color = c.get("primary", Color.PURPLE) if c.get("primary") is Color else Color.PURPLE
	var surf: Color = c.get("surface", Color.DARK_GRAY) if c.get("surface") is Color else Color.DARK_GRAY
	var surf_h: Color = c.get("surface_hover", Color.GRAY) if c.get("surface_hover") is Color else Color.GRAY
	var bg: Color = c.get("background", Color.BLACK) if c.get("background") is Color else Color.BLACK
	var txt: Color = c.get("text", Color.WHITE) if c.get("text") is Color else Color.WHITE
	var muted: Color = c.get("text_muted", Color.DIM_GRAY) if c.get("text_muted") is Color else Color.DIM_GRAY
	var on_pri: Color = c.get("on_primary", Color.WHITE) if c.get("on_primary") is Color else Color.WHITE
	var danger: Color = c.get("danger", Color.RED) if c.get("danger") is Color else Color.RED
	var success: Color = c.get("success", Color.GREEN) if c.get("success") is Color else Color.GREEN
	var accent: Color = c.get("accent", Color.ORANGE) if c.get("accent") is Color else Color.ORANGE
	var rad: int = str(r.get("md", 8)).to_int()
	var rad_lg: int = str(r.get("lg", 16)).to_int()
	var sp_xs: int = str(sp.get("xs", 4)).to_int()
	var sp_sm: int = str(sp.get("sm", 8)).to_int()
	var sp_md: int = str(sp.get("md", 12)).to_int()
	var sp_lg: int = str(sp.get("lg", 16)).to_int()
	var fs_body: int = str(fs.get("body", 16)).to_int()
	var fs_small: int = str(fs.get("small", 12)).to_int()
	var fs_title: int = str(fs.get("title", 20)).to_int()
	var fs_heading: int = str(fs.get("heading", 28)).to_int()
	var mh: int = sp_md + sp_xs
	var mv: int = sp_sm + sp_xs
	var th: Theme = Theme.new()
	th.default_font_size = fs_body
	# Button (taban) ve üç varyasyonu
	_button_set(th, "Button", surf, surf_h, pri, txt, muted, pri * Color(1, 1, 1, 0.4), bw, rad, mh, mv, fs, bg, sp)
	_button_set(th, "PrimaryButton", pri, pri.lightened(0.12), pri.darkened(0.2), on_pri, muted, pri, 0, rad, mh, mv, fs, bg, sp)
	th.set_type_variation("PrimaryButton", "Button")
	_button_set(th, "DangerButton", danger, danger.lightened(0.12), danger.darkened(0.2), Color.WHITE if _contrast(Color.WHITE, danger) >= 4.5 else Color(0.04, 0.05, 0.09), muted, danger, 0, rad, mh, mv, fs, bg, sp)
	th.set_type_variation("DangerButton", "Button")
	_button_set(th, "GhostButton", Color.TRANSPARENT, surf_h, surf, txt, muted, Color.TRANSPARENT, 0, rad, mh, mv, fs, bg, sp)
	th.set_type_variation("GhostButton", "Button")
	# Kart / panel
	var panel: StyleBoxFlat = _flat(surf, surf_h, bw, rad, sp_md, sp_md)
	panel.shadow_size = sp_xs; panel.shadow_color = Color(0, 0, 0, 0.35)
	th.set_stylebox("panel", "Panel", panel)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("panel", "Card", _flat(surf, surf_h, bw, rad_lg, sp_lg, sp_lg))
	th.set_type_variation("Card", "PanelContainer")
	# Metin girişi
	th.set_stylebox("normal", "LineEdit", _flat(bg, surf_h, bw, rad, sp_md, sp_sm))
	th.set_stylebox("focus", "LineEdit", _flat(bg, pri, 2, rad, sp_md, sp_sm))
	th.set_stylebox("read_only", "LineEdit", _flat(surf, surf_h, bw, rad, sp_md, sp_sm))
	th.set_color("font_color", "LineEdit", txt)
	th.set_color("font_placeholder_color", "LineEdit", muted)
	th.set_color("caret_color", "LineEdit", accent)
	th.set_color("selection_color", "LineEdit", pri * Color(1, 1, 1, 0.5))
	th.set_font_size("font_size", "LineEdit", fs_body)
	# İlerleme çubukları
	var bar_r: int = clampi(rad / 2, 2, 8)
	th.set_stylebox("background", "ProgressBar", _flat(bg, surf_h, bw, bar_r, 0, 0))
	th.set_stylebox("fill", "ProgressBar", _flat(pri, Color.TRANSPARENT, 0, bar_r, 0, 0))
	th.set_color("font_color", "ProgressBar", txt)
	for pair: Array in [["HealthBar", success], ["DangerBar", danger], ["AccentBar", accent]]:
		var p_name: String = str(pair[0])
		var p_col: Color = pair[1] if pair[1] is Color else Color.WHITE
		th.set_stylebox("background", p_name, _flat(bg, surf_h, bw, bar_r, 0, 0))
		th.set_stylebox("fill", p_name, _flat(p_col, Color.TRANSPARENT, 0, bar_r, 0, 0))
		th.set_type_variation(p_name, "ProgressBar")
	# Etiketler
	th.set_color("font_color", "Label", txt)
	th.set_font_size("font_size", "Label", fs_body)
	var label_sets: Array = [
		["HeaderLarge", fs_heading, txt], ["HeaderMedium", fs_title, txt], ["Caption", fs_small, muted],
		["AccentLabel", fs_body, accent], ["DangerLabel", fs_body, danger]
	]
	for ls: Array in label_sets:
		var ls_name: String = str(ls[0])
		var ls_size: int = str(ls[1]).to_int()
		var ls_col: Color = ls[2] if ls[2] is Color else Color.WHITE
		th.set_font_size("font_size", ls_name, ls_size)
		th.set_color("font_color", ls_name, ls_col)
		th.set_type_variation(ls_name, "Label")
	th.set_color("default_color", "RichTextLabel", txt)
	th.set_font_size("normal_font_size", "RichTextLabel", fs_body)
	for cls: String in ["CheckBox", "CheckButton", "OptionButton"]:
		th.set_color("font_color", cls, txt)
		th.set_font_size("font_size", cls, fs_body)
	# Düzen sabitleri: ajan boşluğu elle yazmasın, tema versin
	th.set_constant("separation", "VBoxContainer", sp_sm)
	th.set_constant("separation", "HBoxContainer", sp_sm)
	th.set_constant("h_separation", "GridContainer", sp_sm)
	th.set_constant("v_separation", "GridContainer", sp_sm)
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		th.set_constant(side, "MarginContainer", sp_md)
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = surf_h; line.thickness = maxi(bw, 1)
	th.set_stylebox("separator", "HSeparator", line)
	var line_v: StyleBoxLine = StyleBoxLine.new()
	line_v.color = surf_h; line_v.thickness = maxi(bw, 1)
	th.set_stylebox("separator", "VSeparator", line_v)
	return th

static func styled_classes() -> Array[String]:
	return ["Button", "Panel", "PanelContainer", "LineEdit", "ProgressBar", "Label", "RichTextLabel", "CheckBox", "CheckButton", "OptionButton", "VBoxContainer", "HBoxContainer", "GridContainer", "MarginContainer", "HSeparator", "VSeparator"]

static func _button_set(th: Theme, type_name: String, normal: Color, hover: Color, pressed: Color, font: Color, disabled_font: Color, border: Color, bw: int, rad: int, mh: int, mv: int, fs: Dictionary, bg: Color, sp: Dictionary) -> void:
	th.set_stylebox("normal", type_name, _flat(normal, border, bw, rad, mh, mv))
	th.set_stylebox("hover", type_name, _flat(hover, border, bw, rad, mh, mv))
	th.set_stylebox("pressed", type_name, _flat(pressed, Color.WHITE if bw > 0 else Color.TRANSPARENT, maxi(bw, 0) + (1 if bw > 0 else 0), rad, mh, mv))
	var focus: StyleBoxFlat = _flat(Color.TRANSPARENT, Color(0.98, 0.75, 0.14), 2, rad, mh, mv)
	focus.draw_center = false
	th.set_stylebox("focus", type_name, focus)
	th.set_stylebox("disabled", type_name, _flat(bg * Color(1, 1, 1, 0.6), disabled_font * Color(1, 1, 1, 0.2), maxi(bw, 1), rad, mh, mv))
	th.set_color("font_color", type_name, font)
	th.set_color("font_hover_color", type_name, font)
	th.set_color("font_pressed_color", type_name, font)
	th.set_color("font_focus_color", type_name, font)
	th.set_color("font_disabled_color", type_name, disabled_font)
	th.set_font_size("font_size", type_name, str(fs.get("body", 16)).to_int())
	th.set_constant("h_separation", type_name, str(sp.get("sm", 8)).to_int())

static func _flat(bg_c: Color, border_c: Color, bw: int, r: int, mh: int, mv: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_c
	if bw > 0:
		sb.set_border_width_all(bw)
		sb.border_color = border_c
	if r > 0:
		sb.set_corner_radius_all(r)
	sb.content_margin_left = float(mh); sb.content_margin_right = float(mh)
	sb.content_margin_top = float(mv); sb.content_margin_bottom = float(mv)
	return sb

## WCAG kontrast oranı (1..21); audit_ui_layout'un TEXT_LOW_CONTRAST kuralı da bunu kullanır.
static func contrast_ratio(fg: Color, bg: Color) -> float:
	return _contrast(fg, bg)

static func _contrast(fg: Color, bg: Color) -> float:
	return AISidebarRuntimeUiAudit.contrast(fg, AISidebarRuntimeUiAudit._luminance(bg))
