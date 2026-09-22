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
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

var plan: AISidebarImplementationPlan = null
var is_resolved: bool = false

var _vbox: VBoxContainer
var _title_lbl: Label
var _plan_lbl: RichTextLabel
var _buttons_bar: HBoxContainer
var _apply_btn: Button
var _cancel_btn: Button
var _status_lbl: Label

func _init(p_plan: AISidebarImplementationPlan = null) -> void:
	plan = p_plan

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _setup_ui() -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(0.12, 0.16, 0.24, 0.95)
	style.border_color = Color(0.35, 0.65, 0.9, 0.8) # Mavi accent: plan/niyet
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", style)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_theme_constant_override("separation", 6)
	add_child(_vbox)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)

	var icon_lbl = Label.new()
	icon_lbl.text = "📋"
	icon_lbl.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(icon_lbl)

	_title_lbl = Label.new()
	_title_lbl.text = "Implementation Plan"
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_title_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	_title_lbl.add_theme_font_size_override("font_size", 12)
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
	_plan_lbl.add_theme_font_size_override("normal_font_size", 11)
	_plan_lbl.add_theme_color_override("default_color", Color(0.88, 0.92, 0.96))
	_plan_lbl.text = _build_display_text()
	_vbox.add_child(_plan_lbl)

	_buttons_bar = HBoxContainer.new()
	_buttons_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_bar.add_theme_constant_override("separation", 8)
	_vbox.add_child(_buttons_bar)

	_apply_btn = Button.new()
	_apply_btn.text = AISidebarI18n.get_text("btn_plan_apply")
	AISidebarIconHelper.apply_icon(_apply_btn, "check")
	_apply_btn.focus_mode = Control.FOCUS_NONE
	_apply_btn.add_theme_font_size_override("font_size", 11)
	_apply_btn.pressed.connect(_on_apply)
	_buttons_bar.add_child(_apply_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = AISidebarI18n.get_text("btn_plan_cancel")
	AISidebarIconHelper.apply_icon(_cancel_btn, "x")
	_cancel_btn.focus_mode = Control.FOCUS_NONE
	_cancel_btn.add_theme_font_size_override("font_size", 11)
	_cancel_btn.pressed.connect(_on_cancel)
	_buttons_bar.add_child(_cancel_btn)

	_status_lbl = Label.new()
	_status_lbl.visible = false
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
	_vbox.add_child(_status_lbl)

func _build_display_text() -> String:
	if plan == null:
		return "(Plan verisi alınamadı.)"
	return plan.to_markdown()

func mark_applied() -> void:
	is_resolved = true
	_set_buttons_visible(false)
	_set_status("✓ Plan onaylandı, uygulanıyor", Color(0.4, 0.85, 0.5))

func mark_cancelled() -> void:
	is_resolved = true
	_set_buttons_visible(false)
	_set_status("✕ Plan iptal edildi", Color(0.9, 0.5, 0.4))

func _set_buttons_visible(vis: bool) -> void:
	if _apply_btn:
		_apply_btn.disabled = not vis
		_apply_btn.visible = vis
	if _cancel_btn:
		_cancel_btn.disabled = not vis
		_cancel_btn.visible = vis

func _set_status(txt: String, col: Color) -> void:
	if _status_lbl:
		_status_lbl.text = txt
		_status_lbl.add_theme_color_override("font_color", col)
		_status_lbl.visible = true

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
