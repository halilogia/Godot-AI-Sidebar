@tool
extends ConfirmationDialog
class_name AISidebarChangeSetDialog

## Görsel Değişiklik ve Diff Onay Penceresi (ChangeSet Diff & Approval Dialog) (SRP).
## Viewport kısıtları (%85x%80) ve dahili kaydırma (Scroll) ile ideal boyutta açılır.

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")

signal action_approved()
signal action_rejected()

@onready var header_label: RichTextLabel = $Margin/VBox/HeaderLabel
@onready var summary_label: RichTextLabel = $Margin/VBox/SummaryLabel
@onready var diff_rich_text: RichTextLabel = $Margin/VBox/DiffScroll/DiffRichText

var current_change_set: AISidebarChangeSet = null

func _ready() -> void:
	title = AISidebarI18n.get_text("dialog_diff_title")
	ok_button_text = AISidebarI18n.get_text("btn_approve")
	cancel_button_text = AISidebarI18n.get_text("btn_reject")
	unresizable = false
	theme = AISidebarThemeBuilder.build(AISidebarThemeBuilder.Density.FORM)
	get_ok_button().theme_type_variation = AISidebarThemeBuilder.PRIMARY_BUTTON
	get_cancel_button().theme_type_variation = AISidebarThemeBuilder.BUTTON
	var margin := get_node_or_null("Margin") as MarginContainer
	if margin:
		for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			margin.add_theme_constant_override(side, AISidebarTheme.px(AISidebarTheme.SPACE_XS + 2))
		var box := margin.get_node_or_null("VBox") as VBoxContainer
		if box:
			box.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	if diff_rich_text:
		diff_rich_text.theme_type_variation = AISidebarThemeBuilder.RICH_TITLE
	
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)
	
	if header_label:
		header_label.selection_enabled = true
		header_label.context_menu_enabled = true
		header_label.shortcut_keys_enabled = true
		header_label.focus_mode = Control.FOCUS_CLICK
		header_label.deselect_on_focus_loss_enabled = false
		header_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if summary_label:
		summary_label.selection_enabled = true
		summary_label.context_menu_enabled = true
		summary_label.shortcut_keys_enabled = true
		summary_label.focus_mode = Control.FOCUS_CLICK
		summary_label.deselect_on_focus_loss_enabled = false
		summary_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if diff_rich_text:
		diff_rich_text.selection_enabled = true
		diff_rich_text.context_menu_enabled = true
		diff_rich_text.shortcut_keys_enabled = true
		diff_rich_text.focus_mode = Control.FOCUS_CLICK
		diff_rich_text.deselect_on_focus_loss_enabled = false
		diff_rich_text.mouse_filter = Control.MOUSE_FILTER_STOP

func show_change_set(tool_name: String, args: Dictionary, cs: AISidebarChangeSet) -> void:
	current_change_set = cs
	
	if not header_label or not summary_label or not diff_rich_text:
		return
		
	# 1. Viewport Kısıtları Hesaplama (max %85 genişlik x %80 yükseklik)
	var vp_size = Vector2(1280, 720)
	if get_viewport():
		vp_size = get_viewport().get_visible_rect().size
	elif DisplayServer.window_get_size().x > 0:
		vp_size = Vector2(DisplayServer.window_get_size())
		
	var max_w = maxi(580, int(vp_size.x * 0.85))
	var max_h = maxi(420, int(vp_size.y * 0.80))
	var min_w = 520
	var min_h = 360
	
	var target_w = clampi(720, min_w, max_w)
	var target_h = clampi(500, min_h, max_h)
	
	min_size = Vector2i(min_w, min_h)
	max_size = Vector2i(max_w, max_h)
	size = Vector2i(target_w, target_h)
	
	# 2. İçerik ve Diff Doldurma
	if cs:
		var deltas = cs.get_file_deltas()
		header_label.text = "[b][color=" + AISidebarTheme.bb(AISidebarTheme.COLOR_TONE_INFO_TEXT) + "]" + AISidebarI18n.get_text("changes_header", {"count": deltas.size()}) + "[/color][/b]"
		
		var sum_lines: PackedStringArray = []
		for d in deltas:
			sum_lines.append("  • [b]" + d["file_name"] + "[/b] [color=" + AISidebarTheme.bb(AISidebarTheme.COLOR_TONE_SUCCESS_TEXT) + "]+" + str(d["added"]) + "[/color] [color=" + AISidebarTheme.bb(AISidebarTheme.COLOR_TONE_ERROR_TEXT) + "]-" + str(d["removed"]) + "[/color]")
		summary_label.text = "\n".join(sum_lines)
		
		diff_rich_text.text = cs.get_bbcode_diff()
	else:
		header_label.text = "[b][color=" + AISidebarTheme.bb(AISidebarTheme.COLOR_TONE_WARNING_TEXT) + "]" + AISidebarI18n.get_text("dialog_approval_header", {"tool": tool_name}) + "[/color][/b]"
		summary_label.text = AISidebarI18n.get_text("dialog_params", {"args": JSON.stringify(args)})
		diff_rich_text.text = "[color=" + AISidebarTheme.bb(AISidebarTheme.COLOR_TEXT_SECONDARY) + "]" + AISidebarI18n.get_text("dialog_permanent_warning") + "[/color]"
		
	popup_centered(Vector2i(target_w, target_h))

func _on_confirmed() -> void:
	action_approved.emit()

func _on_canceled() -> void:
	action_rejected.emit()
