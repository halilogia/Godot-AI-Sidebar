@tool
extends RefCounted
class_name AISidebarThemeBuilder

## AISidebarTheme belirteçlerinden Godot Theme kaynağı üretir: adlı tip varyasyonları (Tailwind'deki
## bileşen sınıfları gibi). Bir düğüm `theme_type_variation = AISidebarThemeBuilder.CARD` ile stilini
## alır; tema kök düğüme (dock, Ayarlar penceresi) bir kez verilir ve alt düğümlere kendiliğinden geçer.
## Kod ile üretilir çünkü editörün ölçeği (AISidebarTheme.ui_scale) çalışma anında bilinir.
##
## İki yoğunluk: COMPACT (dock, sohbet kartları) ve FORM (Ayarlar gibi geniş pencereler; yazılar editör
## gövde boyunda). Varyasyon adları iki yoğunlukta aynıdır; yalnız boylar değişir.

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

enum Density { COMPACT, FORM }

# Label
const TITLE := "AISidebarTitle"
const BODY := "AISidebarBody"
const HINT := "AISidebarHint"
const MICRO := "AISidebarMicro"
const TITLE_WARNING := "AISidebarTitleWarning"
const TITLE_ERROR := "AISidebarTitleError"
const TITLE_INFO := "AISidebarTitleInfo"
const TEXT_SUCCESS := "AISidebarTextSuccess"
const TEXT_ERROR := "AISidebarTextError"
# RichTextLabel
const RICH_BODY := "AISidebarRichBody"
const RICH_SMALL := "AISidebarRichSmall"
const RICH_TITLE := "AISidebarRichTitle"
# PanelContainer
const CARD := "AISidebarCard"
const CARD_WARNING := "AISidebarCardWarning"
const CARD_QUESTION := "AISidebarCardQuestion"
const CARD_ERROR := "AISidebarCardError"
const CARD_INFO := "AISidebarCardInfo"
const CARD_NEUTRAL := "AISidebarCardNeutral"
const CARD_SUBTLE := "AISidebarCardSubtle"
const CARD_INSET := "AISidebarCardInset"
# Button
const BUTTON := "AISidebarButton"
const PRIMARY_BUTTON := "AISidebarPrimaryButton"
const DANGER_BUTTON := "AISidebarDangerButton"
const GHOST_BUTTON := "AISidebarGhostButton"
const OPTION_BUTTON := "AISidebarOptionChoice"
const LINK_BUTTON := "AISidebarLinkButton"
const NAV_BUTTON := "AISidebarNavButton"
const NAV_BUTTON_ACTIVE := "AISidebarNavButtonActive"
# Metin girişi
const LINE_EDIT := "AISidebarLineEdit"
const TEXT_EDIT := "AISidebarTextEdit"

## Yoğunluğa göre yazı boyları (ölçeklenmiş).
static func sizes(density: Density) -> Dictionary:
	if density == Density.FORM:
		return {
			"title": AISidebarTheme.fs(AISidebarTheme.FONT_SIZE_FORM_TITLE),
			"body": AISidebarTheme.fs(AISidebarTheme.FONT_SIZE_FORM_BODY),
			"hint": AISidebarTheme.fs(AISidebarTheme.FONT_SIZE_FORM_HINT),
			"micro": AISidebarTheme.fs(AISidebarTheme.FONT_SIZE_SMALL + 1),
			"button": AISidebarTheme.fs(AISidebarTheme.FONT_SIZE_FORM_HINT + 1),
		}
	return {
		"title": AISidebarTheme.fs(AISidebarTheme.FONT_SIZE_SUBHEADER),
		"body": AISidebarTheme.fs(AISidebarTheme.FONT_SIZE_BODY),
		"hint": AISidebarTheme.fs(AISidebarTheme.FONT_SIZE_SMALL),
		"micro": AISidebarTheme.fs(AISidebarTheme.FONT_SIZE_MICRO),
		"button": AISidebarTheme.fs(AISidebarTheme.FONT_SIZE_BODY),
	}

static func build(density: Density = Density.COMPACT) -> Theme:
	var t := Theme.new()
	var sz := sizes(density)
	var title: int = sz["title"]
	var body: int = sz["body"]
	var hint: int = sz["hint"]
	var micro: int = sz["micro"]
	var button: int = sz["button"]
	# Formda varyasyonsuz denetimler (onay kutusu, açılır liste, sayı kutusu) gövde boyunu alır; başlık
	# hep gövdeden büyük kalır. Dock'ta editörün kendi boyu korunur.
	if density == Density.FORM:
		t.default_font_size = body

	_label(t, TITLE, title, AISidebarTheme.COLOR_TEXT_PRIMARY)
	_label(t, BODY, body, AISidebarTheme.COLOR_TEXT_PRIMARY)
	_label(t, HINT, hint, AISidebarTheme.COLOR_TEXT_SECONDARY)
	_label(t, MICRO, micro, AISidebarTheme.COLOR_TEXT_MUTED)
	_label(t, TITLE_WARNING, title, AISidebarTheme.COLOR_TONE_WARNING_TEXT)
	_label(t, TITLE_ERROR, title, AISidebarTheme.COLOR_TONE_ERROR_TEXT)
	_label(t, TITLE_INFO, title, AISidebarTheme.COLOR_TONE_INFO_TEXT)
	_label(t, TEXT_SUCCESS, body, AISidebarTheme.COLOR_TONE_SUCCESS_TEXT)
	_label(t, TEXT_ERROR, body, AISidebarTheme.COLOR_TONE_ERROR_TEXT)

	_rich(t, RICH_BODY, body, AISidebarTheme.COLOR_TEXT_PRIMARY)
	_rich(t, RICH_SMALL, hint, AISidebarTheme.COLOR_TEXT_SECONDARY)
	_rich(t, RICH_TITLE, title, AISidebarTheme.COLOR_TEXT_PRIMARY)

	var pad := AISidebarTheme.SPACE_MD if density == Density.FORM else AISidebarTheme.SPACE_SM + 2
	_panel(t, CARD, card_style(AISidebarTheme.COLOR_BG_CARD, AISidebarTheme.COLOR_BORDER_SUBTLE, pad, true))
	_panel(t, CARD_WARNING, card_style(AISidebarTheme.COLOR_TONE_WARNING_BG, AISidebarTheme.COLOR_TONE_WARNING_BORDER, pad, true))
	_panel(t, CARD_QUESTION, card_style(AISidebarTheme.COLOR_TONE_QUESTION_BG, AISidebarTheme.COLOR_TONE_WARNING_BORDER, pad, true))
	_panel(t, CARD_ERROR, card_style(AISidebarTheme.COLOR_TONE_ERROR_BG, AISidebarTheme.COLOR_TONE_ERROR_BORDER, pad, true))
	_panel(t, CARD_INFO, card_style(AISidebarTheme.COLOR_TONE_INFO_BG, AISidebarTheme.COLOR_TONE_INFO_BORDER, pad, true))
	_panel(t, CARD_NEUTRAL, card_style(AISidebarTheme.COLOR_TONE_NEUTRAL_BG, AISidebarTheme.COLOR_TONE_NEUTRAL_BORDER, pad, true))
	_panel(t, CARD_SUBTLE, card_style(AISidebarTheme.COLOR_TONE_SUBTLE_BG, AISidebarTheme.COLOR_TONE_SUBTLE_BORDER, AISidebarTheme.SPACE_SM, false))
	_panel(t, CARD_INSET, card_style(AISidebarTheme.COLOR_BG_APP, AISidebarTheme.COLOR_BORDER_SUBTLE, AISidebarTheme.SPACE_SM, false))

	_button(t, BUTTON, button, _outline(false), _outline(true), _outline(true), AISidebarTheme.COLOR_TEXT_PRIMARY)
	_button(t, PRIMARY_BUTTON, button, AISidebarTheme.create_accent_button_style(), AISidebarTheme.create_accent_button_style(true), AISidebarTheme.create_accent_button_style(false, true), AISidebarTheme.COLOR_WHITE)
	_button(t, DANGER_BUTTON, button, _filled(AISidebarTheme.COLOR_ERROR), _filled(AISidebarTheme.COLOR_ERROR_HOVER), _filled(AISidebarTheme.COLOR_ERROR), AISidebarTheme.COLOR_WHITE)
	_button(t, GHOST_BUTTON, button, AISidebarTheme.create_ghost_button_style(), AISidebarTheme.create_ghost_button_style(true), AISidebarTheme.create_ghost_button_style(true), AISidebarTheme.COLOR_TEXT_SECONDARY)
	_button(t, OPTION_BUTTON, button, _option(false), _option(true), _option(true), AISidebarTheme.COLOR_TEXT_PRIMARY)
	_button(t, LINK_BUTTON, hint, StyleBoxEmpty.new(), StyleBoxEmpty.new(), StyleBoxEmpty.new(), AISidebarTheme.COLOR_TEXT_SECONDARY)
	_button(t, NAV_BUTTON, body, _nav(false, false), _nav(false, true), _nav(false, true), AISidebarTheme.COLOR_TEXT_SECONDARY)
	_button(t, NAV_BUTTON_ACTIVE, body, _nav(true, false), _nav(true, true), _nav(true, true), AISidebarTheme.COLOR_TEXT_PRIMARY)

	for pair: Array in [[LINE_EDIT, "LineEdit"], [TEXT_EDIT, "TextEdit"]]:
		var v: String = pair[0]
		var base: String = pair[1]
		t.set_type_variation(v, base)
		t.set_stylebox("normal", v, AISidebarTheme.create_input_style())
		t.set_stylebox("focus", v, AISidebarTheme.create_input_focus_style())
		t.set_stylebox("read_only", v, AISidebarTheme.create_input_style())
		t.set_font_size("font_size", v, body)
		t.set_color("font_color", v, AISidebarTheme.COLOR_TEXT_PRIMARY)
		t.set_color("font_placeholder_color", v, AISidebarTheme.COLOR_TEXT_MUTED)
	return t

## Kart kutusu: ince kenarlık, yuvarlak köşe, istenirse hafif gölge (derinlik).
static func card_style(bg: Color, border: Color, pad: int, shadow: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(AISidebarTheme.RADIUS_LG)
	s.content_margin_left = AISidebarTheme.px(pad)
	s.content_margin_right = AISidebarTheme.px(pad)
	s.content_margin_top = AISidebarTheme.px(pad)
	s.content_margin_bottom = AISidebarTheme.px(pad)
	if shadow:
		s.shadow_color = AISidebarTheme.COLOR_SHADOW
		s.shadow_size = AISidebarTheme.px(4)
		s.shadow_offset = Vector2(0, AISidebarTheme.px(1))
	return s

static func _label(t: Theme, v: String, size: int, color: Color) -> void:
	t.set_type_variation(v, "Label")
	t.set_font_size("font_size", v, size)
	t.set_color("font_color", v, color)

static func _rich(t: Theme, v: String, size: int, color: Color) -> void:
	t.set_type_variation(v, "RichTextLabel")
	for item: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		t.set_font_size(item, v, size)
	t.set_color("default_color", v, color)

static func _panel(t: Theme, v: String, style: StyleBox) -> void:
	t.set_type_variation(v, "PanelContainer")
	t.set_stylebox("panel", v, style)

static func _button(t: Theme, v: String, size: int, normal: StyleBox, hover: StyleBox, pressed: StyleBox, color: Color) -> void:
	t.set_type_variation(v, "Button")
	t.set_stylebox("normal", v, normal)
	t.set_stylebox("hover", v, hover)
	t.set_stylebox("pressed", v, pressed)
	t.set_stylebox("hover_pressed", v, pressed)
	t.set_stylebox("disabled", v, normal)
	t.set_stylebox("focus", v, StyleBoxEmpty.new())
	t.set_font_size("font_size", v, size)
	t.set_color("font_color", v, color)
	t.set_color("font_hover_color", v, AISidebarTheme.COLOR_WHITE if color == AISidebarTheme.COLOR_WHITE else AISidebarTheme.COLOR_TEXT_PRIMARY)
	t.set_color("font_pressed_color", v, AISidebarTheme.COLOR_WHITE if color == AISidebarTheme.COLOR_WHITE else AISidebarTheme.COLOR_TEXT_PRIMARY)
	t.set_color("font_hover_pressed_color", v, AISidebarTheme.COLOR_WHITE if color == AISidebarTheme.COLOR_WHITE else AISidebarTheme.COLOR_TEXT_PRIMARY)
	t.set_color("font_disabled_color", v, AISidebarTheme.COLOR_TEXT_MUTED)
	t.set_color("icon_normal_color", v, color)
	t.set_color("icon_hover_color", v, AISidebarTheme.COLOR_TEXT_PRIMARY)

static func _outline(hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = AISidebarTheme.COLOR_BG_CARD_HOVER if hover else AISidebarTheme.COLOR_BG_INPUT
	s.border_color = AISidebarTheme.COLOR_BORDER_HOVER if hover else AISidebarTheme.COLOR_BORDER_SUBTLE
	s.set_border_width_all(1)
	s.set_corner_radius_all(AISidebarTheme.RADIUS_SM)
	_pad(s, AISidebarTheme.SPACE_MD, AISidebarTheme.SPACE_XS)
	return s

static func _filled(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(AISidebarTheme.RADIUS_MD)
	_pad(s, AISidebarTheme.SPACE_MD, AISidebarTheme.SPACE_XS + 1)
	return s

static func _option(hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = AISidebarTheme.COLOR_OPTION_BG.lightened(0.08) if hover else AISidebarTheme.COLOR_OPTION_BG
	s.border_color = AISidebarTheme.COLOR_BORDER_FOCUS if hover else AISidebarTheme.COLOR_OPTION_BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(AISidebarTheme.RADIUS_MD)
	_pad(s, AISidebarTheme.SPACE_SM + 2, AISidebarTheme.SPACE_XS + 2)
	return s

static func _nav(active: bool, hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if active:
		s.bg_color = AISidebarTheme.COLOR_BG_ACTIVE
	elif hover:
		s.bg_color = AISidebarTheme.COLOR_BG_CARD_HOVER
	else:
		s.bg_color = AISidebarTheme.COLOR_TRANSPARENT
	s.border_color = AISidebarTheme.COLOR_ACCENT
	s.border_width_left = AISidebarTheme.px(3) if active else 0
	s.set_corner_radius_all(AISidebarTheme.RADIUS_SM)
	_pad(s, AISidebarTheme.SPACE_MD, AISidebarTheme.SPACE_SM - 2)
	return s

static func _pad(s: StyleBoxFlat, h: int, v: int) -> void:
	s.content_margin_left = AISidebarTheme.px(h)
	s.content_margin_right = AISidebarTheme.px(h)
	s.content_margin_top = AISidebarTheme.px(v)
	s.content_margin_bottom = AISidebarTheme.px(v)
