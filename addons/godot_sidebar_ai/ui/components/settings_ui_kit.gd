@tool
extends RefCounted
class_name AISidebarSettingsUi

## Ayarlar penceresinin ortak görsel parçaları: sayfa, kart (başlık + açıklama), ipucu, rozet, düğme,
## form satırı. Bütün sayfalar (sahneden değil kodla kurulur) bu birimi kullanır; böylece kartlar,
## yazı boyları ve düğmeler her sayfada aynıdır. Yazı boyu editörün yazı boyuna göre ölçeklenir
## (sabit piksel yok): base_size pencere açılırken temadan alınır.

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

static var base_size: int = 14

static func title_size() -> int:
	return base_size + 1

static func hint_size() -> int:
	return maxi(9, base_size - 2)

static func badge_size() -> int:
	return maxi(8, base_size - 3)

static func page() -> VBoxContainer:
	var p := VBoxContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_constant_override("separation", AISidebarTheme.SPACE_MD)
	return p

## Başlıklı kart; içerik kutusunu döndürür. hint boşsa açıklama satırı eklenmez.
static func card(parent: Control, title: String, hint: String = "", accessory: Control = null) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_MD))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", AISidebarTheme.SPACE_SM)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", AISidebarTheme.SPACE_SM)
	box.add_child(head)
	var t := Label.new()
	t.text = title
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", title_size())
	t.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	head.add_child(t)
	if accessory != null:
		accessory.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(accessory)
	if not hint.is_empty():
		box.add_child(hint_label(hint))
	return box

static func hint_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", hint_size())
	l.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
	return l

static func body_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	return l

## Durum bildirimi (işlem sonucu); boşken yer kaplamaz.
static func status_label() -> Label:
	var l := hint_label("")
	l.visible = false
	return l

static func set_status(l: Label, text: String, is_error: bool = false) -> void:
	l.text = text
	l.visible = not text.is_empty()
	l.add_theme_color_override("font_color", AISidebarTheme.COLOR_ERROR if is_error else AISidebarTheme.COLOR_SUCCESS)

## Küçük renkli hap (kapsam, durum): "Yerleşik", "Proje", "Açık" gibi.
static func badge(text: String, accent: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_size_override("font_size", badge_size())
	l.add_theme_color_override("font_color", accent.lightened(0.25))
	l.add_theme_stylebox_override("normal", AISidebarTheme.create_pill_style(accent))
	return l

static func set_badge(l: Label, text: String, accent: Color) -> void:
	l.text = text
	l.add_theme_color_override("font_color", accent.lightened(0.25))
	l.add_theme_stylebox_override("normal", AISidebarTheme.create_pill_style(accent))

## İkincil düğme (kenarlıklı, dikeyde uzamaz).
static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("normal", _outline_style(false))
	b.add_theme_stylebox_override("hover", _outline_style(true))
	b.add_theme_stylebox_override("pressed", _outline_style(true))
	b.add_theme_stylebox_override("disabled", _outline_style(false))
	b.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	b.add_theme_font_size_override("font_size", hint_size() + 1)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b

## Birincil düğme (vurgu rengi): sayfadaki asıl eylem.
static func primary_button(text: String, on_press: Callable) -> Button:
	var b := button(text, on_press)
	b.add_theme_stylebox_override("normal", AISidebarTheme.create_accent_button_style())
	b.add_theme_stylebox_override("hover", AISidebarTheme.create_accent_button_style(true))
	b.add_theme_stylebox_override("pressed", AISidebarTheme.create_accent_button_style(false, true))
	b.add_theme_color_override("font_color", AISidebarTheme.COLOR_WHITE)
	b.add_theme_color_override("font_hover_color", AISidebarTheme.COLOR_WHITE)
	return b

static func _outline_style(hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = AISidebarTheme.COLOR_BG_CARD_HOVER if hover else AISidebarTheme.COLOR_BG_INPUT
	s.border_color = AISidebarTheme.COLOR_BORDER_HOVER if hover else AISidebarTheme.COLOR_BORDER_SUBTLE
	s.set_border_width_all(1)
	s.set_corner_radius_all(AISidebarTheme.RADIUS_SM)
	s.content_margin_left = AISidebarTheme.SPACE_MD
	s.content_margin_right = AISidebarTheme.SPACE_MD
	s.content_margin_top = AISidebarTheme.SPACE_XS
	s.content_margin_bottom = AISidebarTheme.SPACE_XS
	return s

## Metin kutusu stilleri (LineEdit / TextEdit / SpinBox'ın satırı).
static func style_input(c: Control) -> void:
	c.add_theme_stylebox_override("normal", AISidebarTheme.create_input_style())
	c.add_theme_stylebox_override("focus", AISidebarTheme.create_input_focus_style())
	c.add_theme_stylebox_override("read_only", AISidebarTheme.create_input_style())

static func line_edit(placeholder: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_input(e)
	return e

## "Etiket: [denetim]" satırı; etiket sabit genişlikte olduğu için satırlar hizalı durur.
static func form_row(parent: Control, label: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", AISidebarTheme.SPACE_SM)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(float(base_size) * 9.0, 0)
	l.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

static func row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", AISidebarTheme.SPACE_SM)
	parent.add_child(r)
	return r

static func spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

## Sol menü düğmesi: normal / üzerinde / seçili hepsi ayrı; yalnız seçili olan vurgulu görünür.
static func style_nav_button(b: Button, active: bool) -> void:
	b.add_theme_stylebox_override("normal", _nav_style(active, false))
	b.add_theme_stylebox_override("hover", _nav_style(active, true))
	b.add_theme_stylebox_override("pressed", _nav_style(active, true))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var color := AISidebarTheme.COLOR_TEXT_PRIMARY if active else AISidebarTheme.COLOR_TEXT_SECONDARY
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	b.add_theme_color_override("font_pressed_color", AISidebarTheme.COLOR_TEXT_PRIMARY)

static func _nav_style(active: bool, hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if active:
		s.bg_color = AISidebarTheme.COLOR_BG_ACTIVE
	elif hover:
		s.bg_color = AISidebarTheme.COLOR_BG_CARD_HOVER
	else:
		s.bg_color = AISidebarTheme.COLOR_TRANSPARENT
	s.border_color = AISidebarTheme.COLOR_ACCENT
	s.border_width_left = 3 if active else 0
	s.set_corner_radius_all(AISidebarTheme.RADIUS_SM)
	s.content_margin_left = AISidebarTheme.SPACE_MD
	s.content_margin_right = AISidebarTheme.SPACE_SM
	s.content_margin_top = AISidebarTheme.SPACE_SM - 2
	s.content_margin_bottom = AISidebarTheme.SPACE_SM - 2
	return s
