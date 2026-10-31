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
	var overrides: Dictionary = args.get("tokens", {}) as Dictionary if args.get("tokens") is Dictionary else {}
	var color_over: Dictionary = overrides.get("color", {}) as Dictionary if overrides.get("color") is Dictionary else {}
	var colors: Dictionary = {}
	for key: String in (PRESETS[preset] as Dictionary):
		var hex: String = str(PRESETS[preset][key])
		var legacy_arg: String = ""
		for arg_name: String in LEGACY_COLOR_ARGS:
			if LEGACY_COLOR_ARGS[arg_name] == key:
				legacy_arg = arg_name
		if not legacy_arg.is_empty() and args.has(legacy_arg):
			hex = str(args[legacy_arg])
		if color_over.has(key):
			hex = str(color_over[key])
		colors[key] = Color.from_string(hex, Color.from_string(str(PRESETS[preset][key]), Color.MAGENTA))
	var primary: Color = colors["primary"]
	var on_primary: Color = Color.WHITE if _contrast(Color.WHITE, primary) >= _contrast(Color(0.04, 0.05, 0.09), primary) else Color(0.04, 0.05, 0.09)
	colors["on_primary"] = on_primary
	var radius_over: Dictionary = overrides.get("radius", {}) as Dictionary if overrides.get("radius") is Dictionary else {}
	var rad_md: int = clampi(int(radius_over.get("md", args.get("corner_radius", 8))), 0, 32)
	var radius: Dictionary = {
		"sm": clampi(int(radius_over.get("sm", maxi(2, rad_md / 2) if rad_md > 0 else 0)), 0, 32),
		"md": rad_md,
		"lg": clampi(int(radius_over.get("lg", rad_md * 2)), 0, 48)
	}
	var space_over: Dictionary = overrides.get("spacing", {}) as Dictionary if overrides.get("spacing") is Dictionary else {}
	var unit: int = clampi(int(args.get("spacing_unit", 4)), 1, 16)
	var spacing: Dictionary = {}
	var steps: Dictionary = {"xs": 1, "sm": 2, "md": 3, "lg": 4, "xl": 6}
	for key: String in steps:
		spacing[key] = clampi(int(space_over.get(key, int(steps[key]) * unit)), 0, 128)
	var font_over: Dictionary = overrides.get("font_size", {}) as Dictionary if overrides.get("font_size") is Dictionary else {}
	var body: int = clampi(int(font_over.get("body", args.get("font_size_body", 16))), 8, 72)
	var font_size: Dictionary = {
		"body": body,
		"small": clampi(int(font_over.get("small", args.get("font_size_small", roundi(body * 0.75)))), 6, 72),
		"title": clampi(int(font_over.get("title", args.get("font_size_title", roundi(body * 1.375)))), 8, 96),
		"heading": clampi(int(font_over.get("heading", roundi(body * 1.75))), 8, 128)
	}
	return {
		"preset": preset, "color": colors, "radius": radius, "spacing": spacing, "font_size": font_size,
		"border_width": clampi(int(overrides.get("border_width", 1)), 0, 8)
	}

static func tokens_to_json(tokens: Dictionary) -> Dictionary:
	var out: Dictionary = tokens.duplicate(true)
	var hex: Dictionary = {}
	for key: String in (tokens["color"] as Dictionary):
		hex[key] = "#" + (tokens["color"][key] as Color).to_html(false)
	out["color"] = hex
	out["schema"] = "ui-tokens/1"
	out["variations"] = VARIATIONS
	return out

static func contrast_report(tokens: Dictionary) -> Dictionary:
	var colors: Dictionary = tokens["color"]
	var checks: Array[Dictionary] = []
	var warnings: Array[String] = []
	for pair: Array in CONTRAST_PAIRS:
		var ratio: float = _contrast(colors[pair[0]], colors[pair[1]])
		var ok: bool = ratio >= float(pair[2])
		checks.append({"foreground": pair[0], "background": pair[1], "ratio": snappedf(ratio, 0.01), "minimum": pair[2], "passed": ok})
		if not ok:
			warnings.append("Düşük kontrast: '%s' / '%s' = %.2f:1 (asgari %.1f:1)." % [pair[0], pair[1], ratio, float(pair[2])])
	return {"checks": checks, "warnings": warnings, "passed": warnings.is_empty()}

static func build_theme(tokens: Dictionary) -> Theme:
	var c: Dictionary = tokens["color"]
	var r: Dictionary = tokens["radius"]
	var sp: Dictionary = tokens["spacing"]
	var fs: Dictionary = tokens["font_size"]
	var bw: int = int(tokens["border_width"])
	var pri: Color = c["primary"]
	var surf: Color = c["surface"]
	var surf_h: Color = c["surface_hover"]
	var bg: Color = c["background"]
	var txt: Color = c["text"]
	var muted: Color = c["text_muted"]
	var on_pri: Color = c["on_primary"]
	var rad: int = int(r["md"])
	var mh: int = int(sp["md"]) + int(sp["xs"])
	var mv: int = int(sp["sm"]) + int(sp["xs"])
	var th: Theme = Theme.new()
	th.default_font_size = int(fs["body"])
	# Button (taban) ve üç varyasyonu
	_button_set(th, "Button", surf, surf_h, pri, txt, muted, pri * Color(1, 1, 1, 0.4), bw, rad, mh, mv, fs, bg, sp)
	_button_set(th, "PrimaryButton", pri, pri.lightened(0.12), pri.darkened(0.2), on_pri, muted, pri, 0, rad, mh, mv, fs, bg, sp)
	th.set_type_variation("PrimaryButton", "Button")
	_button_set(th, "DangerButton", c["danger"], (c["danger"] as Color).lightened(0.12), (c["danger"] as Color).darkened(0.2), Color.WHITE if _contrast(Color.WHITE, c["danger"]) >= 4.5 else Color(0.04, 0.05, 0.09), muted, c["danger"], 0, rad, mh, mv, fs, bg, sp)
	th.set_type_variation("DangerButton", "Button")
	_button_set(th, "GhostButton", Color.TRANSPARENT, surf_h, surf, txt, muted, Color.TRANSPARENT, 0, rad, mh, mv, fs, bg, sp)
	th.set_type_variation("GhostButton", "Button")
	# Kart / panel
	var panel: StyleBoxFlat = _flat(surf, surf_h, bw, rad, int(sp["md"]), int(sp["md"]))
	panel.shadow_size = int(sp["xs"]); panel.shadow_color = Color(0, 0, 0, 0.35)
	th.set_stylebox("panel", "Panel", panel)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("panel", "Card", _flat(surf, surf_h, bw, int(r["lg"]), int(sp["lg"]), int(sp["lg"])))
	th.set_type_variation("Card", "PanelContainer")
	# Metin girişi
	th.set_stylebox("normal", "LineEdit", _flat(bg, surf_h, bw, rad, int(sp["md"]), int(sp["sm"])))
	th.set_stylebox("focus", "LineEdit", _flat(bg, pri, 2, rad, int(sp["md"]), int(sp["sm"])))
	th.set_stylebox("read_only", "LineEdit", _flat(surf, surf_h, bw, rad, int(sp["md"]), int(sp["sm"])))
	th.set_color("font_color", "LineEdit", txt)
	th.set_color("font_placeholder_color", "LineEdit", muted)
	th.set_color("caret_color", "LineEdit", c["accent"])
	th.set_color("selection_color", "LineEdit", pri * Color(1, 1, 1, 0.5))
	th.set_font_size("font_size", "LineEdit", int(fs["body"]))
	# İlerleme çubukları
	var bar_r: int = clampi(rad / 2, 2, 8)
	th.set_stylebox("background", "ProgressBar", _flat(bg, surf_h, bw, bar_r, 0, 0))
	th.set_stylebox("fill", "ProgressBar", _flat(pri, Color.TRANSPARENT, 0, bar_r, 0, 0))
	th.set_color("font_color", "ProgressBar", txt)
	for pair: Array in [["HealthBar", c["success"]], ["DangerBar", c["danger"]], ["AccentBar", c["accent"]]]:
		th.set_stylebox("background", str(pair[0]), _flat(bg, surf_h, bw, bar_r, 0, 0))
		th.set_stylebox("fill", str(pair[0]), _flat(pair[1], Color.TRANSPARENT, 0, bar_r, 0, 0))
		th.set_type_variation(str(pair[0]), "ProgressBar")
	# Etiketler
	th.set_color("font_color", "Label", txt)
	th.set_font_size("font_size", "Label", int(fs["body"]))
	var label_sets: Array = [
		["HeaderLarge", int(fs["heading"]), txt], ["HeaderMedium", int(fs["title"]), txt], ["Caption", int(fs["small"]), muted],
		["AccentLabel", int(fs["body"]), c["accent"]], ["DangerLabel", int(fs["body"]), c["danger"]]
	]
	for ls: Array in label_sets:
		th.set_font_size("font_size", str(ls[0]), int(ls[1]))
		th.set_color("font_color", str(ls[0]), ls[2])
		th.set_type_variation(str(ls[0]), "Label")
	th.set_color("default_color", "RichTextLabel", txt)
	th.set_font_size("normal_font_size", "RichTextLabel", int(fs["body"]))
	for cls: String in ["CheckBox", "CheckButton", "OptionButton"]:
		th.set_color("font_color", cls, txt)
		th.set_font_size("font_size", cls, int(fs["body"]))
	# Düzen sabitleri: ajan boşluğu elle yazmasın, tema versin
	th.set_constant("separation", "VBoxContainer", int(sp["sm"]))
	th.set_constant("separation", "HBoxContainer", int(sp["sm"]))
	th.set_constant("h_separation", "GridContainer", int(sp["sm"]))
	th.set_constant("v_separation", "GridContainer", int(sp["sm"]))
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		th.set_constant(side, "MarginContainer", int(sp["md"]))
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = surf_h; line.thickness = maxi(bw, 1)
	th.set_stylebox("separator", "HSeparator", line)
	th.set_stylebox("separator", "VSeparator", line.duplicate())
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
	th.set_font_size("font_size", type_name, int(fs["body"]))
	th.set_constant("h_separation", type_name, int(sp["sm"]))

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

static func _contrast(fg: Color, bg: Color) -> float:
	return AISidebarRuntimeUiAudit.contrast(fg, AISidebarRuntimeUiAudit._luminance(bg))
