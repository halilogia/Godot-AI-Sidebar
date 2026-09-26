@tool
extends RefCounted
class_name AISidebarSettingsUi

## Ayarlar penceresinin ve form benzeri görünümlerin ortak parçaları: sayfa, kart (başlık + açıklama),
## ipucu, rozet, düğme, form satırı, açılır liste. Görünüm AISidebarThemeBuilder'ın tip varyasyonlarından
## gelir (kökteki tema, FORM yoğunluğu); bu birim yalnız düzeni kurar ve varyasyon adını atar. Yazı boyu
## ve boşluk editör ölçeğiyle büyür; burada sabit piksel ya da renk yoktur.

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")

## Gövde yazı boyu (ölçekli); en küçük genişlik / yükseklik hesaplarının birimi.
static var base_size: int = AISidebarTheme.FONT_SIZE_FORM_BODY

## Kökte kullanılacak tema (Ayarlar penceresi, Skills penceresi); base_size'ı da günceller.
static func form_theme() -> Theme:
	var sz := AISidebarThemeBuilder.sizes(AISidebarThemeBuilder.Density.FORM)
	base_size = sz["body"]
	return AISidebarThemeBuilder.build(AISidebarThemeBuilder.Density.FORM)

static func page() -> VBoxContainer:
	var p := VBoxContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_MD))
	return p

## Başlıklı kart; içerik kutusunu döndürür. hint boşsa açıklama satırı eklenmez.
static func card(parent: Control, title: String, hint: String = "", accessory: Control = null) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.theme_type_variation = AISidebarThemeBuilder.CARD
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	panel.add_child(box)
	var head := row(box)
	var t := Label.new()
	t.text = title
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.theme_type_variation = AISidebarThemeBuilder.TITLE
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
	l.theme_type_variation = AISidebarThemeBuilder.HINT
	return l

static func body_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.theme_type_variation = AISidebarThemeBuilder.BODY
	return l

## Durum bildirimi (işlem sonucu); boşken yer kaplamaz.
static func status_label() -> Label:
	var l := hint_label("")
	l.visible = false
	return l

static func set_status(l: Label, text: String, is_error: bool = false) -> void:
	l.text = text
	l.visible = not text.is_empty()
	l.theme_type_variation = AISidebarThemeBuilder.TEXT_ERROR if is_error else AISidebarThemeBuilder.TEXT_SUCCESS

## Küçük renkli hap (kapsam, durum): "Yerleşik", "Proje", "Açık" gibi. Renk veriden geldiği için
## stil burada, tema belirteçleriyle üretilir.
static func badge(text: String, accent: Color) -> Label:
	var l := Label.new()
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.theme_type_variation = AISidebarThemeBuilder.MICRO
	set_badge(l, text, accent)
	return l

static func set_badge(l: Label, text: String, accent: Color) -> void:
	l.text = text
	l.add_theme_color_override("font_color", AISidebarTheme.emphasize(accent, 0.25))
	l.add_theme_stylebox_override("normal", AISidebarTheme.create_pill_style(accent))

## İkincil düğme (kenarlıklı, dikeyde uzamaz).
static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.theme_type_variation = AISidebarThemeBuilder.BUTTON
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b

## Birincil düğme (vurgu rengi): sayfadaki asıl eylem.
static func primary_button(text: String, on_press: Callable) -> Button:
	var b := button(text, on_press)
	b.theme_type_variation = AISidebarThemeBuilder.PRIMARY_BUTTON
	return b

## Açılır liste: en uzun seçeneğe göre genişlemez (uzun seçenek pencereyi ekran dışına itmesin), sığmayan
## metin üç noktayla kesilir.
static func option_button() -> OptionButton:
	var o := OptionButton.new()
	o.fit_to_longest_item = false
	o.clip_text = true
	o.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return o

## Metin kutusu stilleri (LineEdit / TextEdit).
static func style_input(c: Control) -> void:
	c.theme_type_variation = AISidebarThemeBuilder.TEXT_EDIT if c is TextEdit else AISidebarThemeBuilder.LINE_EDIT

static func line_edit(placeholder: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_input(e)
	return e

## "Etiket: [denetim]" satırı; etiket sabit genişlikte olduğu için satırlar hizalı durur.
static func form_row(parent: Control, label: String, control: Control) -> HBoxContainer:
	var r := row(parent)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(float(base_size) * 9.0, 0)
	l.theme_type_variation = AISidebarThemeBuilder.HINT
	r.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(control)
	return r

static func row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	parent.add_child(r)
	return r

static func spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

## Sol menü düğmesi: yalnız seçili olan vurgulu; üzerine gelme ayrı görünür.
static func style_nav_button(b: Button, active: bool) -> void:
	b.theme_type_variation = AISidebarThemeBuilder.NAV_BUTTON_ACTIVE if active else AISidebarThemeBuilder.NAV_BUTTON
