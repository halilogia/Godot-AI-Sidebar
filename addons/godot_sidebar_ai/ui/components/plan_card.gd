@tool
extends PanelContainer
class_name AISidebarPlanCard

## Uygulama Planı Kartı (Implementation Plan Card) (SRP).
##
## AMAC:
##   Ajandan gelen yapılandırılmış planı kullanıcıya gösterir ve
##   [Planı Uygula] / [İptal] kararını toplar.
##
## MEVCUT MİMARİYLE UYUM:
##   ApprovalCard ile aynı yaşam döngüsü: signal yayar, kendini "resolved"
##   işaretler, butonları gizler. Modal popup AÇILMAZ.
##
## GIZLI REASONING GÖSTERİLMEZ:
##   Metin tamamen AISidebarImplementationPlan.to_markdown() çıktısıdır.

signal plan_applied()
signal plan_cancelled()

const AISidebarImplementationPlan = preload("res://addons/godot_sidebar_ai/core/types/implementation_plan.gd")
const AISidebarMarkdownRenderer = preload("res://addons/godot_sidebar_ai/ui/presenters/markdown_renderer.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarStatusIcon = preload("res://addons/godot_sidebar_ai/ui/components/status_icon.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")

var plan: AISidebarImplementationPlan = null
var is_resolved: bool = false

var _vbox: VBoxContainer
var _title_lbl: Label
var _plan_lbl: RichTextLabel
var _buttons_bar: HBoxContainer
var _apply_btn: Button
var _cancel_btn: Button
var _status_lbl: Label
var _status_icon: AISidebarStatusIcon

func _init(p_plan: AISidebarImplementationPlan = null) -> void:
	plan = p_plan

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _setup_ui() -> void:
	theme_type_variation = AISidebarThemeBuilder.CARD_INFO
	mouse_filter = Control.MOUSE_FILTER_PASS

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_theme_constant_override("separation", AISidebarTheme.px(6))
	add_child(_vbox)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", AISidebarTheme.px(6))

	var header_icon = AISidebarStatusIcon.new(AISidebarTheme.ICON_SIZE_LG)
	header_icon.set_icon("list-checks", AISidebarTheme.COLOR_TONE_INFO_TEXT)
	header_hbox.add_child(header_icon)

	_title_lbl = Label.new()
	_title_lbl.text = AISidebarI18n.get_text("plan_title")
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_title_lbl.theme_type_variation = AISidebarThemeBuilder.TITLE_INFO
	header_hbox.add_child(_title_lbl)
	_vbox.add_child(header_hbox)

	_plan_lbl = RichTextLabel.new()
	_plan_lbl.bbcode_enabled = true
	_plan_lbl.fit_content = true
	_plan_lbl.scroll_active = false
	_plan_lbl.selection_enabled = true
	_plan_lbl.context_menu_enabled = true
	_plan_lbl.shortcut_keys_enabled = true
	_plan_lbl.focus_mode = Control.FOCUS_CLICK
	_plan_lbl.deselect_on_focus_loss_enabled = false
	_plan_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	_plan_lbl.theme_type_variation = AISidebarThemeBuilder.RICH_BODY
	_plan_lbl.text = AISidebarMarkdownRenderer.to_bbcode(_build_display_text())
	_vbox.add_child(_plan_lbl)

	_buttons_bar = HBoxContainer.new()
	_buttons_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_bar.add_theme_constant_override("separation", AISidebarTheme.px(8))
	_vbox.add_child(_buttons_bar)

	_apply_btn = Button.new()
	_apply_btn.text = AISidebarI18n.get_text("btn_plan_apply")
	AISidebarIconHelper.apply_icon(_apply_btn, "check")
	_apply_btn.focus_mode = Control.FOCUS_NONE
	_apply_btn.theme_type_variation = AISidebarThemeBuilder.PRIMARY_BUTTON
	_apply_btn.pressed.connect(_on_apply)
	_buttons_bar.add_child(_apply_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = AISidebarI18n.get_text("btn_plan_cancel")
	AISidebarIconHelper.apply_icon(_cancel_btn, "x")
	_cancel_btn.focus_mode = Control.FOCUS_NONE
	_cancel_btn.theme_type_variation = AISidebarThemeBuilder.BUTTON
	_cancel_btn.pressed.connect(_on_cancel)
	_buttons_bar.add_child(_cancel_btn)

	var status_row = HBoxContainer.new()
	status_row.visible = false
	status_row.add_theme_constant_override("separation", AISidebarTheme.px(4))
	_vbox.add_child(status_row)
	_status_icon = AISidebarStatusIcon.new()
	status_row.add_child(_status_icon)
	_status_lbl = Label.new()
	_status_lbl.visible = false
	_status_lbl.theme_type_variation = AISidebarThemeBuilder.TEXT_SUCCESS
	status_row.add_child(_status_lbl)

func _build_display_text() -> String:
	if plan == null:
		return AISidebarI18n.get_text("plan_no_data")
	return plan.to_markdown()

func mark_applied() -> void:
	is_resolved = true
	_set_buttons_visible(false)
	_set_status(AISidebarI18n.get_text("plan_status_applied"), AISidebarTheme.COLOR_TONE_SUCCESS_TEXT, "check")

func mark_cancelled() -> void:
	is_resolved = true
	_set_buttons_visible(false)
	_set_status(AISidebarI18n.get_text("plan_status_cancelled"), AISidebarTheme.COLOR_TONE_ERROR_TEXT, "x")

func _set_buttons_visible(vis: bool) -> void:
	if _apply_btn:
		_apply_btn.disabled = not vis
		_apply_btn.visible = vis
	if _cancel_btn:
		_cancel_btn.disabled = not vis
		_cancel_btn.visible = vis

func _set_status(txt: String, col: Color, icon_name: String) -> void:
	if _status_lbl:
		_status_lbl.text = txt
		_status_lbl.add_theme_color_override("font_color", col)
		_status_lbl.visible = true
		_status_icon.set_icon(icon_name, col)
		_status_lbl.get_parent().visible = true

func _on_apply() -> void:
	if is_resolved:
		return
	mark_applied()
	plan_applied.emit()

func _on_cancel() -> void:
	if is_resolved:
		return
	mark_cancelled()
	plan_cancelled.emit()
