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
## Onay kartı: tonlu zemin + solda vurgu şeridi (uyarı / tehlike / sonuçlanmış).
const CARD_APPROVAL := "AISidebarCardApproval"
const CARD_APPROVAL_DANGER := "AISidebarCardApprovalDanger"
const CARD_APPROVAL_DONE := "AISidebarCardApprovalDone"
## Kod / yol kutusu (eş genişlikli yazı için zemin) ve ikon çipi.
const CODE_BOX := "AISidebarCodeBox"
const ICON_CHIP_WARNING := "AISidebarIconChipWarning"
const ICON_CHIP_DANGER := "AISidebarIconChipDanger"
const ICON_CHIP_SUCCESS := "AISidebarIconChipSuccess"
# Button
const BUTTON := "AISidebarButton"
const PRIMARY_BUTTON := "AISidebarPrimaryButton"
const DANGER_BUTTON := "AISidebarDangerButton"
const GHOST_BUTTON := "AISidebarGhostButton"
const OPTION_BUTTON := "AISidebarOptionChoice"
## Onay kartının eylem düğmeleri: tonlu (dolgu değil), Gönder düğmesine benzemez.
const APPROVE_BUTTON := "AISidebarApproveButton"
const APPROVE_DANGER_BUTTON := "AISidebarApproveDangerButton"
const LINK_BUTTON := "AISidebarLinkButton"
const NAV_BUTTON := "AISidebarNavButton"
const NAV_BUTTON_ACTIVE := "AISidebarNavButtonActive"
# Dock iskeleti (başlık, model çubuğu, giriş alanı)
const APP_PANEL := "AISidebarAppPanel"
const HEADER_TITLE := "AISidebarHeaderTitle"
const STATUS_TEXT := "AISidebarStatusText"
const HEADER_BUTTON := "AISidebarHeaderButton"
const ICON_BUTTON := "AISidebarIconButton"
const SELECT := "AISidebarSelect"
const PILL_BUTTON := "AISidebarPillButton"
const LIST := "AISidebarList"
const POPUP_PANEL := "AISidebarPopupPanel"
const FLOAT_BUTTON := "AISidebarFloatButton"
const SEND_BUTTON := "AISidebarSendButton"
const STOP_BUTTON := "AISidebarStopButton"
# Liste ve bölüm panelleri (geçmiş paneli gibi)
const SECTION_PANEL := "AISidebarSectionPanel"
const LIST_ITEM := "AISidebarListItem"
const LIST_ITEM_HOVER := "AISidebarListItemHover"
const LIST_ITEM_ACTIVE := "AISidebarListItemActive"
const ACCENT_BAR := "AISidebarAccentBar"
const ACCENT_LINK_BUTTON := "AISidebarAccentLinkButton"
# Sohbet akışı (balonlar, açılır kartlar, küçük düğmeler)
const BUBBLE_USER := "AISidebarBubbleUser"
const BUBBLE_ASSISTANT := "AISidebarBubbleAssistant"
const BUBBLE_COMMAND := "AISidebarBubbleCommand"
const ROLE_USER := "AISidebarRoleUser"
const ROLE_ASSISTANT := "AISidebarRoleAssistant"
const ROLE_COMMAND := "AISidebarRoleCommand"
const CARD_COMPACT := "AISidebarCardCompact"
const EXPAND_HEADER := "AISidebarExpandHeader"
const EXPAND_HEADER_SMALL := "AISidebarExpandHeaderSmall"
const CHIP_BUTTON := "AISidebarChipButton"
const DANGER_LINK_BUTTON := "AISidebarDangerLinkButton"
const HINT_MUTED := "AISidebarHintMuted"
const LABEL_SMALL := "AISidebarLabelSmall"
const RICH_MUTED := "AISidebarRichMuted"
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
		t.set_stylebox("panel", "AcceptDialog", AISidebarTheme.create_dialog_style())
		# Pencere çerçevesi ve başlık çubuğu da paletten (açık temada koyu çerçeve kalmasın).
		for frame_item: String in ["embedded_border", "embedded_unfocused_border"]:
			var base_frame: StyleBox = source_theme().get_stylebox(frame_item, "Window")
			if base_frame is StyleBoxFlat:
				var frame: StyleBoxFlat = base_frame.duplicate()
				frame.bg_color = AISidebarTheme.COLOR_BG_CARD_HOVER if frame_item == "embedded_border" else AISidebarTheme.COLOR_BG_CARD
				frame.border_color = AISidebarTheme.COLOR_BORDER_HOVER
				t.set_stylebox(frame_item, "Window", frame)
		t.set_color("title_color", "Window", AISidebarTheme.COLOR_TEXT_PRIMARY)

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
	_panel(t, CARD_APPROVAL, _accent_card(AISidebarTheme.COLOR_TONE_WARNING_BG, AISidebarTheme.COLOR_TONE_WARNING_BORDER, AISidebarTheme.COLOR_TONE_WARNING_TEXT, pad))
	_panel(t, CARD_APPROVAL_DANGER, _accent_card(AISidebarTheme.COLOR_TONE_ERROR_BG, AISidebarTheme.COLOR_TONE_ERROR_BORDER, AISidebarTheme.COLOR_TONE_ERROR_TEXT, pad))
	_panel(t, CARD_APPROVAL_DONE, _accent_card(AISidebarTheme.COLOR_TONE_SUBTLE_BG, AISidebarTheme.COLOR_TONE_SUBTLE_BORDER, AISidebarTheme.COLOR_BORDER_HOVER, pad))
	var code := card_style(AISidebarTheme.COLOR_BG_APP, AISidebarTheme.COLOR_BORDER_SUBTLE, AISidebarTheme.SPACE_SM, false)
	code.set_corner_radius_all(AISidebarTheme.RADIUS_SM)
	code.content_margin_top = AISidebarTheme.px(AISidebarTheme.SPACE_XS + 1)
	code.content_margin_bottom = AISidebarTheme.px(AISidebarTheme.SPACE_XS + 1)
	_panel(t, CODE_BOX, code)
	_panel(t, ICON_CHIP_WARNING, _chip(AISidebarTheme.COLOR_TONE_WARNING_TEXT))
	_panel(t, ICON_CHIP_DANGER, _chip(AISidebarTheme.COLOR_TONE_ERROR_TEXT))
	_panel(t, ICON_CHIP_SUCCESS, _chip(AISidebarTheme.COLOR_TONE_SUCCESS_TEXT))

	_button(t, BUTTON, button, _outline(false), _outline(true), _outline(true), AISidebarTheme.COLOR_TEXT_PRIMARY)
	_button(t, PRIMARY_BUTTON, button, AISidebarTheme.create_accent_button_style(), AISidebarTheme.create_accent_button_style(true), AISidebarTheme.create_accent_button_style(false, true), AISidebarTheme.COLOR_WHITE)
	_button(t, DANGER_BUTTON, button, _filled(AISidebarTheme.COLOR_ERROR_FILL), _filled(AISidebarTheme.COLOR_ERROR_FILL_HOVER), _filled(AISidebarTheme.COLOR_ERROR_FILL), AISidebarTheme.COLOR_WHITE)
	_button(t, GHOST_BUTTON, button, AISidebarTheme.create_ghost_button_style(), AISidebarTheme.create_ghost_button_style(true), AISidebarTheme.create_ghost_button_style(true), AISidebarTheme.COLOR_TEXT_SECONDARY)
	_button(t, OPTION_BUTTON, button, _option(false), _option(true), _option(true), AISidebarTheme.COLOR_TEXT_PRIMARY)
	_button(t, APPROVE_BUTTON, button, _tonal(AISidebarTheme.COLOR_TONE_WARNING_TEXT, false), _tonal(AISidebarTheme.COLOR_TONE_WARNING_TEXT, true), _tonal(AISidebarTheme.COLOR_TONE_WARNING_TEXT, true), AISidebarTheme.emphasize(AISidebarTheme.COLOR_TONE_WARNING_TEXT))
	_button(t, APPROVE_DANGER_BUTTON, button, _tonal(AISidebarTheme.COLOR_TONE_ERROR_TEXT, false), _tonal(AISidebarTheme.COLOR_TONE_ERROR_TEXT, true), _tonal(AISidebarTheme.COLOR_TONE_ERROR_TEXT, true), AISidebarTheme.emphasize(AISidebarTheme.COLOR_TONE_ERROR_TEXT))
	_button(t, LINK_BUTTON, hint, StyleBoxEmpty.new(), StyleBoxEmpty.new(), StyleBoxEmpty.new(), AISidebarTheme.COLOR_TEXT_SECONDARY)
	_button(t, NAV_BUTTON, body, _nav(false, false), _nav(false, true), _nav(false, true), AISidebarTheme.COLOR_TEXT_SECONDARY)
	_button(t, NAV_BUTTON_ACTIVE, body, _nav(true, false), _nav(true, true), _nav(true, true), AISidebarTheme.COLOR_TEXT_PRIMARY)

	# Dock iskeleti
	_panel(t, APP_PANEL, AISidebarTheme.create_app_bg_style())
	_label(t, HEADER_TITLE, AISidebarTheme.fs(AISidebarTheme.FONT_SIZE_HEADER), AISidebarTheme.COLOR_TEXT_PRIMARY)
	_label(t, STATUS_TEXT, hint, AISidebarTheme.COLOR_SUCCESS)
	_button(t, HEADER_BUTTON, hint, AISidebarTheme.create_ghost_button_style(), AISidebarTheme.create_ghost_button_style(true), AISidebarTheme.create_ghost_button_style(true), AISidebarTheme.COLOR_TEXT_SECONDARY)
	_button(t, ICON_BUTTON, body, AISidebarTheme.create_ghost_button_style(), AISidebarTheme.create_ghost_button_style(true), AISidebarTheme.create_ghost_button_style(true), AISidebarTheme.COLOR_TEXT_SECONDARY)
	t.set_type_variation(SELECT, "OptionButton")
	t.set_stylebox("normal", SELECT, AISidebarTheme.create_input_style())
	t.set_stylebox("hover", SELECT, AISidebarTheme.create_card_hover_style())
	t.set_stylebox("pressed", SELECT, AISidebarTheme.create_card_active_style())
	t.set_stylebox("focus", SELECT, focus_ring())
	t.set_font_size("font_size", SELECT, body)
	t.set_color("font_color", SELECT, AISidebarTheme.COLOR_TEXT_PRIMARY)
	t.set_color("font_hover_color", SELECT, AISidebarTheme.COLOR_TEXT_PRIMARY)
	t.set_type_variation(PILL_BUTTON, "Button")
	t.set_font_size("font_size", PILL_BUTTON, hint)
	t.set_constant("h_separation", PILL_BUTTON, AISidebarTheme.px(AISidebarTheme.SPACE_XXS + 1))
	t.set_stylebox("focus", PILL_BUTTON, focus_ring(AISidebarTheme.RADIUS_PILL))
	t.set_type_variation(LIST, "ItemList")
	t.set_font_size("font_size", LIST, body)
	_panel(t, POPUP_PANEL, AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XS))
	_button(t, FLOAT_BUTTON, hint, AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XXS), AISidebarTheme.create_card_hover_style(AISidebarTheme.SPACE_XXS), AISidebarTheme.create_card_hover_style(AISidebarTheme.SPACE_XXS), AISidebarTheme.COLOR_TEXT_SECONDARY)
	_button(t, SEND_BUTTON, body, AISidebarTheme.create_accent_button_style(), AISidebarTheme.create_accent_button_style(true), AISidebarTheme.create_accent_button_style(false, true), AISidebarTheme.COLOR_WHITE)
	_button(t, STOP_BUTTON, body, _filled(AISidebarTheme.COLOR_ERROR_FILL), _filled(AISidebarTheme.COLOR_ERROR_FILL_HOVER), _filled(AISidebarTheme.COLOR_ERROR_FILL), AISidebarTheme.COLOR_WHITE)
	for v: String in [SEND_BUTTON, STOP_BUTTON]:
		t.set_color("icon_normal_color", v, AISidebarTheme.COLOR_WHITE)
		t.set_color("icon_hover_color", v, AISidebarTheme.COLOR_WHITE)
		t.set_color("icon_pressed_color", v, AISidebarTheme.COLOR_WHITE)

	# Liste ve bölüm panelleri
	var section := card_style(AISidebarTheme.COLOR_BG_APP, AISidebarTheme.COLOR_BORDER_SUBTLE, AISidebarTheme.SPACE_SM, false)
	section.set_corner_radius_all(AISidebarTheme.RADIUS_MD)
	_panel(t, SECTION_PANEL, section)
	_panel(t, LIST_ITEM, AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_SM))
	_panel(t, LIST_ITEM_HOVER, AISidebarTheme.create_card_hover_style(AISidebarTheme.SPACE_SM))
	_panel(t, LIST_ITEM_ACTIVE, AISidebarTheme.create_card_style(true, AISidebarTheme.SPACE_SM))
	var bar := StyleBoxFlat.new()
	bar.bg_color = AISidebarTheme.COLOR_ACCENT
	bar.set_corner_radius_all(AISidebarTheme.RADIUS_SM)
	t.set_type_variation(ACCENT_BAR, "Panel")
	t.set_stylebox("panel", ACCENT_BAR, bar)
	_button(t, ACCENT_LINK_BUTTON, hint, StyleBoxEmpty.new(), AISidebarTheme.create_ghost_button_style(true), AISidebarTheme.create_ghost_button_style(true), AISidebarTheme.COLOR_ACCENT)

	# Sohbet akışı
	_panel(t, BUBBLE_USER, AISidebarTheme.create_bubble_user_style())
	_panel(t, BUBBLE_ASSISTANT, AISidebarTheme.create_bubble_assistant_style())
	_panel(t, BUBBLE_COMMAND, AISidebarTheme.create_bubble_command_style())
	_label(t, ROLE_USER, hint, AISidebarTheme.COLOR_ACCENT)
	_label(t, ROLE_ASSISTANT, hint, AISidebarTheme.COLOR_TEXT_SECONDARY)
	_label(t, ROLE_COMMAND, hint, AISidebarTheme.COLOR_ROLE_COMMAND)
	_panel(t, CARD_COMPACT, AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XS))
	# Düz (zeminsiz) başlık düğmeleri: varsayılan düğme kadar iç boşluk (satır yüksekliği korunur).
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = AISidebarTheme.px(AISidebarTheme.SPACE_XS)
	flat.content_margin_right = AISidebarTheme.px(AISidebarTheme.SPACE_XS)
	flat.content_margin_top = AISidebarTheme.px(AISidebarTheme.SPACE_XS)
	flat.content_margin_bottom = AISidebarTheme.px(AISidebarTheme.SPACE_XS)
	_button(t, EXPAND_HEADER, body, flat, flat, flat, AISidebarTheme.COLOR_TEXT_SECONDARY)
	_button(t, EXPAND_HEADER_SMALL, hint, flat, flat, flat, AISidebarTheme.COLOR_TEXT_MUTED)
	_button(t, CHIP_BUTTON, hint, AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XS), AISidebarTheme.create_card_hover_style(AISidebarTheme.SPACE_XS), AISidebarTheme.create_card_active_style(AISidebarTheme.SPACE_XS), AISidebarTheme.COLOR_TEXT_SECONDARY)
	_button(t, DANGER_LINK_BUTTON, hint, AISidebarTheme.create_ghost_button_style(), AISidebarTheme.create_ghost_button_style(true), AISidebarTheme.create_ghost_button_style(true), AISidebarTheme.COLOR_ERROR)
	t.set_color("font_hover_color", DANGER_LINK_BUTTON, AISidebarTheme.COLOR_ERROR_HOVER)
	_label(t, HINT_MUTED, hint, AISidebarTheme.COLOR_TEXT_MUTED)
	_label(t, LABEL_SMALL, hint, AISidebarTheme.COLOR_TEXT_PRIMARY)
	_rich(t, RICH_MUTED, hint, AISidebarTheme.COLOR_TEXT_MUTED)

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
	_base_types(t, body)
	_complete_variations(t, source_theme())
	return t

## Klavye odak halkası: yalnız kenarlık (zemin çizilmez), vurgu renginde, denetimin biraz dışında.
## Fareyle tıklamada da görünür; Tab ile gezen kullanıcı nerede olduğunu görür.
static func focus_ring(radius: int = AISidebarTheme.RADIUS_MD) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = AISidebarTheme.COLOR_BORDER_FOCUS
	s.set_border_width_all(AISidebarTheme.px(2))
	s.set_corner_radius_all(radius)
	s.set_expand_margin_all(AISidebarTheme.px(2))
	return s

## Varyasyonsuz denetimler (onay kutusu, açılır liste, sayı kutusu, açılır menü …) de paletin yazı
## rengini ve giriş stilini alır; açık / koyu temada okunur kalır.
static func _base_types(t: Theme, body: int) -> void:
	for type_name: String in ["Label", "Button", "CheckBox", "CheckButton", "OptionButton", "MenuButton", "LinkButton", "LineEdit", "TextEdit", "ItemList", "PopupMenu", "Tree"]:
		t.set_color("font_color", type_name, AISidebarTheme.COLOR_TEXT_PRIMARY)
		t.set_color("font_hover_color", type_name, AISidebarTheme.COLOR_TEXT_PRIMARY)
		t.set_color("font_pressed_color", type_name, AISidebarTheme.COLOR_TEXT_PRIMARY)
		t.set_color("font_hover_pressed_color", type_name, AISidebarTheme.COLOR_TEXT_PRIMARY)
		t.set_color("font_focus_color", type_name, AISidebarTheme.COLOR_TEXT_PRIMARY)
		t.set_color("font_disabled_color", type_name, AISidebarTheme.COLOR_TEXT_MUTED)
	for type_name: String in ["Button", "CheckBox", "CheckButton", "OptionButton", "MenuButton", "LinkButton", "ItemList", "Tree"]:
		t.set_stylebox("focus", type_name, focus_ring())
	t.set_color("default_color", "RichTextLabel", AISidebarTheme.COLOR_TEXT_PRIMARY)
	t.set_color("font_placeholder_color", "LineEdit", AISidebarTheme.COLOR_TEXT_MUTED)
	t.set_color("font_placeholder_color", "TextEdit", AISidebarTheme.COLOR_TEXT_MUTED)
	for type_name: String in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", type_name, AISidebarTheme.create_input_style())
		t.set_stylebox("focus", type_name, AISidebarTheme.create_input_focus_style())
		t.set_stylebox("read_only", type_name, AISidebarTheme.create_input_style())
	t.set_stylebox("normal", "OptionButton", AISidebarTheme.create_input_style())
	t.set_stylebox("hover", "OptionButton", AISidebarTheme.create_card_hover_style())
	t.set_stylebox("pressed", "OptionButton", AISidebarTheme.create_card_active_style())
	var popup := AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XS)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", AISidebarTheme.create_card_active_style(AISidebarTheme.SPACE_XS))
	t.set_color("font_color", "TooltipLabel", AISidebarTheme.COLOR_TEXT_PRIMARY)
	t.set_stylebox("panel", "TooltipPanel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XS))
	if body > 0:
		t.set_font_size("font_size", "TooltipLabel", body)

## Varyasyonların devraldığı kaynak tema: editörde editör teması (yazı tipleri, ikonlar editörle aynı),
## editör dışında Godot'nun varsayılan teması.
static func source_theme() -> Theme:
	if Engine.is_editor_hint():
		var editor_theme: Theme = EditorInterface.get_editor_theme()
		if editor_theme != null:
			return editor_theme
	return ThemeDB.get_default_theme()

## Varyasyonda tanımlanmamış öğeler temel tipten kaynak temadan açıkça kopyalanır. (Godot bir
## varyasyonun eksik öğesini başka temalarda temel tipinden aramaz; örn. RichTextLabel'ın kalın yazı
## tipi bulunamayıp düz yazı tipine düşüyordu.)
static func _complete_variations(t: Theme, source: Theme) -> void:
	var data_types: Array[Theme.DataType] = [Theme.DATA_TYPE_COLOR, Theme.DATA_TYPE_CONSTANT, Theme.DATA_TYPE_FONT, Theme.DATA_TYPE_FONT_SIZE, Theme.DATA_TYPE_ICON, Theme.DATA_TYPE_STYLEBOX]
	for v: String in t.get_type_list():
		var base: StringName = t.get_type_variation_base(v)
		if base == &"":
			continue
		for dt: Theme.DataType in data_types:
			for item: String in source.get_theme_item_list(dt, base):
				if not t.has_theme_item(dt, item, v):
					t.set_theme_item(dt, item, v, source.get_theme_item(dt, item, base))

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

## Tonlu kart (onay kartı): soluk vurgu kenarlığı; soldaki vurgu şeridini kart kendisi çizer (ayrı çubuk).
static func _accent_card(bg: Color, border: Color, stripe: Color, pad: int) -> StyleBoxFlat:
	var s := card_style(bg, border, pad, true)
	s.border_color = Color(stripe, 0.38)
	return s

## Yuvarlak ikon çipi: vurgu renginin soluk dolgusu.
static func _chip(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(accent, 0.16)
	s.border_color = Color(accent, 0.35)
	s.set_border_width_all(1)
	s.set_corner_radius_all(AISidebarTheme.RADIUS_PILL)
	_pad(s, AISidebarTheme.SPACE_XS + 1, AISidebarTheme.SPACE_XS + 1)
	return s

## Tonlu düğme: soluk dolgu + renkli kenarlık (birincil mavi dolgulu Gönder'den ayrışır).
static func _tonal(accent: Color, hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(accent, 0.26 if hover else 0.16)
	s.border_color = Color(accent, 0.85 if hover else 0.55)
	s.set_border_width_all(1)
	s.set_corner_radius_all(AISidebarTheme.RADIUS_MD)
	_pad(s, AISidebarTheme.SPACE_MD + 2, AISidebarTheme.SPACE_XS + 1)
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
	t.set_font("mono_font", v, AISidebarTheme.mono_font())

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
	t.set_stylebox("focus", v, focus_ring())
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
	s.bg_color = AISidebarTheme.emphasize(AISidebarTheme.COLOR_OPTION_BG, 0.08) if hover else AISidebarTheme.COLOR_OPTION_BG
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
