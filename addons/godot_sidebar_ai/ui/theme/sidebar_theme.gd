@tool
extends RefCounted
class_name AISidebarTheme

## Merkezi UI Tasarım Sistemi (Central Design System) (SRP).
## Tüm eklenti bileşenleri için ortak renk paleti, tipografi boyutları,
## kenar boşlukları (spacing) ve StyleBox üretim yardımcılarını sağlar.

# 0. Ölçek: editörün ölçeği (EditorInterface.get_editor_scale, plugin.gd atar; editör dışında 1.0).
# Yazı boyu, boşluk ve ikon boyu fs() / px() üzerinden ölçeklenir; sabit piksel doğrudan kullanılmaz.
static var ui_scale: float = 1.0

static func fs(size: int) -> int:
	return maxi(1, roundi(float(size) * ui_scale))

static func px(value: int) -> int:
	return roundi(float(value) * ui_scale)

static var _mono_font: SystemFont = null

## İşletim sisteminin eş genişlikli yazı tipi (Windows / macOS / Linux sırasıyla denenir).
static func mono_font() -> Font:
	if _mono_font == null:
		_mono_font = SystemFont.new()
		_mono_font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "JetBrains Mono", "SF Mono", "Menlo", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	return _mono_font

## BBCode [color=...] için belirteç rengi ("#rrggbb"); metin içinde sabit onaltılık renk yazılmaz.
static func bb(color: Color) -> String:
	return "#" + color.to_html(false)

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
const RADIUS_PILL: int = 999

# 3. Typography Tokens
const FONT_SIZE_MICRO: int = 9
const FONT_SIZE_SMALL: int = 10
const FONT_SIZE_BODY: int = 11
const FONT_SIZE_SUBHEADER: int = 12
const FONT_SIZE_HEADER: int = 13
# Pencere / form yoğunluğu (Ayarlar gibi geniş diyaloglar): editör gövde yazısıyla aynı ölçek.
const FONT_SIZE_FORM_HINT: int = 12
const FONT_SIZE_FORM_BODY: int = 14
const FONT_SIZE_FORM_TITLE: int = 15

# İkon boyları
const ICON_SIZE_SM: int = 12
const ICON_SIZE_MD: int = 14
const ICON_SIZE_LG: int = 16

# 4. Color Palette Tokens (Modern Slate & Midnight Dark)
const COLOR_BG_APP = Color(0.07, 0.08, 0.11, 1.0)
const COLOR_BG_CARD = Color(0.11, 0.13, 0.17, 0.98)
const COLOR_BG_CARD_HOVER = Color(0.16, 0.18, 0.24, 0.98)
const COLOR_BG_INPUT = Color(0.12, 0.14, 0.18, 1.0)
const COLOR_BG_ACTIVE = Color(0.15, 0.22, 0.34, 0.98)

const COLOR_BORDER_SUBTLE = Color(0.18, 0.21, 0.28, 1.0)
const COLOR_BORDER_HOVER = Color(0.28, 0.33, 0.44, 1.0)
const COLOR_BORDER_FOCUS = Color(0.35, 0.60, 0.95, 1.0)

const COLOR_TEXT_PRIMARY = Color(0.90, 0.92, 0.96, 1.0)
const COLOR_TEXT_SECONDARY = Color(0.65, 0.70, 0.78, 1.0)
const COLOR_TEXT_MUTED = Color(0.45, 0.48, 0.55, 1.0)

const COLOR_SUCCESS = Color(0.25, 0.80, 0.45, 1.0)
const COLOR_WARNING = Color(0.90, 0.70, 0.25, 1.0)
const COLOR_ERROR = Color(0.90, 0.35, 0.35, 1.0)
const COLOR_ERROR_HOVER = Color(1.0, 0.45, 0.45, 1.0)
const COLOR_ACCENT = Color(0.30, 0.55, 0.95, 1.0)
const COLOR_ACCENT_HOVER = Color(0.38, 0.62, 0.98, 1.0)
const COLOR_ACCENT_PRESSED = Color(0.20, 0.45, 0.80, 1.0)

# Semantik Renk ve Balon Tokenları (Design Tokens)
const COLOR_BUBBLE_USER = Color(0.14, 0.20, 0.30, 0.95)
const COLOR_BUBBLE_USER_BORDER = Color(0.25, 0.38, 0.55, 0.75)
const COLOR_BUBBLE_ASSISTANT = Color(0.11, 0.13, 0.17, 0.98)
const COLOR_BUBBLE_COMMAND = Color(0.15, 0.14, 0.22, 0.95)
const COLOR_BUBBLE_COMMAND_BORDER = Color(0.35, 0.30, 0.55, 0.7)
const COLOR_ROLE_COMMAND = Color(0.75, 0.55, 0.95, 1.0)
const COLOR_MODE_FULL_AUTO = Color(0.85, 0.55, 0.95, 1.0)
const COLOR_WHITE = Color(1.0, 1.0, 1.0, 1.0)
# Ton renkleri (kartların anlamı): uyarı / soru (kehribar), hata (kırmızı), bilgi / plan (mavi), başarı (yeşil)
const COLOR_TONE_WARNING_BG = Color(0.20, 0.16, 0.10, 0.95)
const COLOR_TONE_WARNING_BORDER = Color(0.90, 0.65, 0.20, 0.70)
const COLOR_TONE_WARNING_TEXT = Color(1.00, 0.75, 0.30, 1.0)
const COLOR_TONE_QUESTION_BG = Color(0.13, 0.16, 0.22, 0.95)
const COLOR_TONE_ERROR_BG = Color(0.22, 0.12, 0.12, 0.90)
const COLOR_TONE_ERROR_BORDER = Color(0.80, 0.30, 0.30, 0.70)
const COLOR_TONE_ERROR_TEXT = Color(0.95, 0.42, 0.42, 1.0)
const COLOR_TONE_INFO_BG = Color(0.12, 0.16, 0.24, 0.95)
const COLOR_TONE_INFO_BORDER = Color(0.35, 0.65, 0.90, 0.80)
const COLOR_TONE_INFO_TEXT = Color(0.60, 0.85, 1.00, 1.0)
const COLOR_TONE_SUCCESS_TEXT = Color(0.40, 0.85, 0.50, 1.0)
const COLOR_TONE_NEUTRAL_BG = Color(0.14, 0.16, 0.20, 0.95)
const COLOR_TONE_NEUTRAL_BORDER = Color(0.30, 0.40, 0.55, 0.60)
const COLOR_TONE_SUBTLE_BG = Color(0.12, 0.14, 0.18, 0.80)
const COLOR_TONE_SUBTLE_BORDER = Color(0.22, 0.27, 0.34, 0.45)
const COLOR_OPTION_BG = Color(0.20, 0.25, 0.35, 0.90)
const COLOR_OPTION_BORDER = Color(0.40, 0.55, 0.75, 0.80)
const COLOR_SHADOW = Color(0.0, 0.0, 0.0, 0.28)

# Bağlam katmanları (sistem istemi / kurallar / skill'ler / araçlar) ve kapsam rozetleri
const COLOR_LAYER_SYSTEM = Color(0.95, 0.75, 0.35, 1.0)
const COLOR_LAYER_RULES = Color(0.35, 0.60, 0.95, 1.0)
const COLOR_LAYER_SKILLS = Color(0.45, 0.80, 0.50, 1.0)
const COLOR_LAYER_TOOLS = Color(0.70, 0.50, 0.90, 1.0)
# Devre dışı bir bölümü soluklaştırma (modulate)
const MODULATE_DISABLED = Color(1.0, 1.0, 1.0, 0.45)
const COLOR_TRANSPARENT = Color(0, 0, 0, 0)

# 5. Factory Metotları
static func create_app_bg_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_APP
	style.set_border_width_all(0)
	style.content_margin_left = px(SPACE_SM)
	style.content_margin_right = px(SPACE_SM)
	style.content_margin_top = px(SPACE_SM)
	style.content_margin_bottom = px(SPACE_SM)
	return style

static func create_card_style(is_active: bool = false, custom_margin: int = SPACE_SM) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_ACTIVE if is_active else COLOR_BG_CARD
	style.border_color = COLOR_BORDER_FOCUS if is_active else COLOR_BORDER_SUBTLE
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_MD)
	style.content_margin_left = px(custom_margin)
	style.content_margin_right = px(custom_margin)
	style.content_margin_top = px(custom_margin)
	style.content_margin_bottom = px(custom_margin)
	return style

static func create_card_hover_style(custom_margin: int = SPACE_SM) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_CARD_HOVER
	style.border_color = COLOR_BORDER_HOVER
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_MD)
	style.content_margin_left = px(custom_margin)
	style.content_margin_right = px(custom_margin)
	style.content_margin_top = px(custom_margin)
	style.content_margin_bottom = px(custom_margin)
	return style

static func create_card_active_style(custom_margin: int = SPACE_SM) -> StyleBoxFlat:
	return create_card_style(true, custom_margin)

static func create_input_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_INPUT
	style.border_color = COLOR_BORDER_SUBTLE
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_SM)
	style.content_margin_left = px(SPACE_SM)
	style.content_margin_right = px(SPACE_SM)
	style.content_margin_top = px(SPACE_SM)
	style.content_margin_bottom = px(SPACE_SM)
	return style

static func create_input_focus_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_INPUT
	style.border_color = COLOR_BORDER_FOCUS
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_SM)
	style.content_margin_left = px(SPACE_SM)
	style.content_margin_right = px(SPACE_SM)
	style.content_margin_top = px(SPACE_SM)
	style.content_margin_bottom = px(SPACE_SM)
	return style

static func create_dialog_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_APP
	style.border_color = COLOR_BORDER_SUBTLE
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_LG)
	style.content_margin_left = px(SPACE_MD)
	style.content_margin_right = px(SPACE_MD)
	style.content_margin_top = px(SPACE_MD)
	style.content_margin_bottom = px(SPACE_MD)
	return style

static func create_bubble_user_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BUBBLE_USER
	style.border_color = COLOR_BUBBLE_USER_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_LG)
	style.content_margin_left = px(10)
	style.content_margin_right = px(10)
	style.content_margin_top = px(8)
	style.content_margin_bottom = px(8)
	return style

static func create_bubble_assistant_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BUBBLE_ASSISTANT
	style.border_color = COLOR_BORDER_SUBTLE
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_LG)
	style.content_margin_left = px(10)
	style.content_margin_right = px(10)
	style.content_margin_top = px(8)
	style.content_margin_bottom = px(8)
	return style

static func create_bubble_command_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BUBBLE_COMMAND
	style.border_color = COLOR_BUBBLE_COMMAND_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_LG)
	style.content_margin_left = px(10)
	style.content_margin_right = px(10)
	style.content_margin_top = px(8)
	style.content_margin_bottom = px(8)
	return style

static func create_accent_button_style(is_hover: bool = false, is_pressed: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	if is_pressed:
		style.bg_color = COLOR_ACCENT_PRESSED
	elif is_hover:
		style.bg_color = COLOR_ACCENT_HOVER
	else:
		style.bg_color = COLOR_ACCENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(RADIUS_MD)
	style.content_margin_left = px(SPACE_MD)
	style.content_margin_right = px(SPACE_MD)
	style.content_margin_top = px(SPACE_XS + 1)
	style.content_margin_bottom = px(SPACE_XS + 1)
	return style

static func create_ghost_button_style(is_hover: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	if is_hover:
		style.bg_color = COLOR_BG_CARD_HOVER
		style.border_color = COLOR_BORDER_HOVER
		style.set_border_width_all(1)
	else:
		style.bg_color = COLOR_TRANSPARENT
		style.set_border_width_all(0)
	style.set_corner_radius_all(RADIUS_SM)
	style.content_margin_left = px(SPACE_XS + 2)
	style.content_margin_right = px(SPACE_XS + 2)
	style.content_margin_top = px(SPACE_XXS + 1)
	style.content_margin_bottom = px(SPACE_XXS + 1)
	return style

## Renkli durum hapı (onay modu gibi): vurgu renginin soluk dolgusu + ince kenarlık, tam yuvarlak.
static func create_pill_style(accent: Color, is_hover: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(accent, 0.20 if is_hover else 0.12)
	style.border_color = Color(accent, 0.70 if is_hover else 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_PILL)
	style.content_margin_left = px(SPACE_SM)
	style.content_margin_right = px(SPACE_SM + 1)
	style.content_margin_top = px(SPACE_XXS + 1)
	style.content_margin_bottom = px(SPACE_XXS + 1)
	return style
