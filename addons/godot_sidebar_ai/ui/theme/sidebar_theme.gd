@tool
extends RefCounted
class_name AISidebarTheme

## Merkezi UI Tasarım Sistemi (Central Design System) (SRP).
## Tüm eklenti bileşenleri için ortak renk paleti, tipografi boyutları,
## kenar boşlukları (spacing) ve StyleBox üretim yardımcılarını sağlar.

# 1. Spacing Tokens (8pt grid türevleri)
const SPACE_XXS: int = 2
const SPACE_XS: int = 4
const SPACE_SM: int = 8
const SPACE_MD: int = 12
const SPACE_LG: int = 16
const SPACE_XL: int = 24

# 2. Corner Radius Tokens
const RADIUS_SM: int = 4
const RADIUS_MD: int = 6
const RADIUS_LG: int = 8

# 3. Typography Tokens
const FONT_SIZE_MICRO: int = 9
const FONT_SIZE_SMALL: int = 10
const FONT_SIZE_BODY: int = 11
const FONT_SIZE_SUBHEADER: int = 12
const FONT_SIZE_HEADER: int = 13

# 4. Color Palette Tokens (Modern Slate & Midnight Dark)
const COLOR_BG_APP = Color(0.08, 0.09, 0.12, 1.0)
const COLOR_BG_CARD = Color(0.12, 0.14, 0.18, 0.98)
const COLOR_BG_CARD_HOVER = Color(0.16, 0.18, 0.24, 0.98)
const COLOR_BG_INPUT = Color(0.14, 0.15, 0.20, 1.0)
const COLOR_BG_ACTIVE = Color(0.15, 0.22, 0.34, 0.98)

const COLOR_BORDER_SUBTLE = Color(0.20, 0.23, 0.30, 1.0)
const COLOR_BORDER_HOVER = Color(0.30, 0.35, 0.45, 1.0)
const COLOR_BORDER_FOCUS = Color(0.30, 0.55, 0.95, 1.0)

const COLOR_TEXT_PRIMARY = Color(0.90, 0.92, 0.96, 1.0)
const COLOR_TEXT_SECONDARY = Color(0.65, 0.70, 0.78, 1.0)
const COLOR_TEXT_MUTED = Color(0.45, 0.48, 0.55, 1.0)

const COLOR_SUCCESS = Color(0.25, 0.80, 0.45, 1.0)
const COLOR_WARNING = Color(0.90, 0.70, 0.25, 1.0)
const COLOR_ERROR = Color(0.90, 0.35, 0.35, 1.0)
const COLOR_ACCENT = Color(0.35, 0.60, 0.95, 1.0)

# 5. Factory Metotları
static func create_card_style(is_active: bool = false, custom_margin: int = SPACE_SM) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_ACTIVE if is_active else COLOR_BG_CARD
	style.border_color = COLOR_BORDER_FOCUS if is_active else COLOR_BORDER_SUBTLE
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_MD)
	style.content_margin_left = custom_margin
	style.content_margin_right = custom_margin
	style.content_margin_top = custom_margin
	style.content_margin_bottom = custom_margin
	return style

static func create_card_hover_style(custom_margin: int = SPACE_SM) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_CARD_HOVER
	style.border_color = COLOR_BORDER_HOVER
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_MD)
	style.content_margin_left = custom_margin
	style.content_margin_right = custom_margin
	style.content_margin_top = custom_margin
	style.content_margin_bottom = custom_margin
	return style

static func create_input_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_INPUT
	style.border_color = COLOR_BORDER_SUBTLE
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_SM)
	style.content_margin_left = SPACE_SM
	style.content_margin_right = SPACE_SM
	style.content_margin_top = SPACE_XS
	style.content_margin_bottom = SPACE_XS
	return style

static func create_dialog_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_APP
	style.border_color = COLOR_BORDER_SUBTLE
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_LG)
	style.content_margin_left = SPACE_MD
	style.content_margin_right = SPACE_MD
	style.content_margin_top = SPACE_MD
	style.content_margin_bottom = SPACE_MD
	return style
