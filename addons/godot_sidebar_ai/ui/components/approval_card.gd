@tool
extends PanelContainer
class_name AISidebarApprovalCard

## İzin ve Onay Kartı Bileşeni (Approval Card) (SRP).
## Riskli işlemler (dosya silme, script ezme, sahne mutasyonu) için TEK YETKİLİ etkileşim kartıdır.
## Modal popup açılmaz; onay doğrudan bu kart üzerinden yönetilir.
##
## Düzen: solda risk renginde şerit; başlıkta ikon çipi, "Onay gerekli" ve risk rozeti (Silme / Yazma /
## Kalıcı); gövdede işlem fiili, hedef (eş genişlikli kutuda yol ya da kural) ve sonucu anlatan ipucu;
## altta Farkı gör (bağlantı) ile sağa yaslı Reddet ve tonlu Onayla. Sonuçlanınca kart sadeleşir.

signal action_approved()
signal action_rejected()
signal view_diff_requested(change_set: AISidebarChangeSet)

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarPermissionPolicy = preload("res://addons/godot_sidebar_ai/core/security/permission_policy.gd")
const AISidebarMarkdownRenderer = preload("res://addons/godot_sidebar_ai/ui/presenters/markdown_renderer.gd")

var tool_name: String = ""
var args: Dictionary = {}
var change_set: AISidebarChangeSet = null
var is_resolved: bool = false

var _is_danger: bool = false
var _stripe: ColorRect
var _chip: PanelContainer
var _title_icon: TextureRect
var _title_lbl: Label
var _risk_badge: Label
var _verb_lbl: Label
var _target_box: PanelContainer
var _target_lbl: RichTextLabel
var _hint_lbl: Label
var _buttons_bar: HBoxContainer
var _approve_btn: Button
var _reject_btn: Button
var _diff_btn: Button

func _init(p_tool: String = "", p_args: Dictionary = {}, p_cs: AISidebarChangeSet = null) -> void:
	tool_name = p_tool
	args = p_args
	change_set = p_cs

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _setup_ui() -> void:
	_is_danger = AISidebarPermissionPolicy.get_tool_risk(tool_name) == AISidebarPermissionPolicy.RiskLevel.DESTRUCTIVE
	theme_type_variation = AISidebarThemeBuilder.CARD_APPROVAL_DANGER if _is_danger else AISidebarThemeBuilder.CARD_APPROVAL
	mouse_filter = Control.MOUSE_FILTER_PASS
	var tone := AISidebarTheme.COLOR_TONE_ERROR_TEXT if _is_danger else AISidebarTheme.COLOR_TONE_WARNING_TEXT

	# Solda risk renginde dikey vurgu şeridi, sağda içerik.
	var frame := HBoxContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM + 2))
	add_child(frame)
	_stripe = ColorRect.new()
	_stripe.custom_minimum_size = Vector2(AISidebarTheme.px(3), 0)
	_stripe.color = tone
	_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_stripe)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	frame.add_child(vbox)

	# Başlık: ikon çipi + başlık + risk rozeti
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	vbox.add_child(head)
	_chip = PanelContainer.new()
	_chip.theme_type_variation = AISidebarThemeBuilder.ICON_CHIP_DANGER if _is_danger else AISidebarThemeBuilder.ICON_CHIP_WARNING
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_chip)
	_title_icon = AISidebarIconHelper.make_icon_rect(AISidebarTheme.ICON_SIZE_MD)
	AISidebarIconHelper.set_rect_icon(_title_icon, "trash" if _is_danger else "shield-alert", tone, AISidebarTheme.ICON_SIZE_MD)
	_chip.add_child(_title_icon)
	_title_lbl = Label.new()
	_title_lbl.text = AISidebarI18n.get_text("approval_title")
	_title_lbl.theme_type_variation = AISidebarThemeBuilder.TITLE_ERROR if _is_danger else AISidebarThemeBuilder.TITLE_WARNING
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(_title_lbl)
	var risk_text := _risk_text()
	if not risk_text.is_empty():
		_risk_badge = Label.new()
		_risk_badge.text = risk_text
		_risk_badge.theme_type_variation = AISidebarThemeBuilder.MICRO
		_risk_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_risk_badge.add_theme_color_override("font_color", AISidebarTheme.emphasize(tone, 0.2))
		_risk_badge.add_theme_stylebox_override("normal", AISidebarTheme.create_pill_style(tone))
		head.add_child(_risk_badge)

	# Gövde: fiil + hedef + ipucu
	_verb_lbl = Label.new()
	_verb_lbl.text = _verb_text()
	_verb_lbl.theme_type_variation = AISidebarThemeBuilder.BODY
	_verb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_verb_lbl)
	var target := _target_text()
	if not target.is_empty():
		_target_box = PanelContainer.new()
		_target_box.theme_type_variation = AISidebarThemeBuilder.CODE_BOX
		vbox.add_child(_target_box)
		# Seçilip kopyalanabilir (yol / kural metni).
		_target_lbl = RichTextLabel.new()
		_target_lbl.bbcode_enabled = false
		_target_lbl.text = target
		_target_lbl.fit_content = true
		_target_lbl.scroll_active = false
		_target_lbl.selection_enabled = true
		_target_lbl.context_menu_enabled = true
		_target_lbl.shortcut_keys_enabled = true
		_target_lbl.deselect_on_focus_loss_enabled = false
		_target_lbl.focus_mode = Control.FOCUS_CLICK
		_target_lbl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		_target_lbl.theme_type_variation = AISidebarThemeBuilder.RICH_BODY
		_target_lbl.add_theme_font_override("normal_font", AISidebarMarkdownRenderer.mono_font())
		_target_box.add_child(_target_lbl)
	var hint := _hint_text()
	if not hint.is_empty():
		_hint_lbl = Label.new()
		_hint_lbl.text = hint
		_hint_lbl.theme_type_variation = AISidebarThemeBuilder.HINT
		_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(_hint_lbl)

	# Eylemler: Farkı gör solda, Reddet + Onayla sağda
	_buttons_bar = HBoxContainer.new()
	_buttons_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_bar.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	vbox.add_child(_buttons_bar)
	if change_set:
		_diff_btn = Button.new()
		_diff_btn.text = AISidebarI18n.get_text("btn_view_diff")
		_diff_btn.theme_type_variation = AISidebarThemeBuilder.LINK_BUTTON
		AISidebarIconHelper.apply_tinted_icon(_diff_btn, "diff", AISidebarTheme.COLOR_TEXT_SECONDARY, AISidebarTheme.ICON_SIZE_SM)
		_diff_btn.pressed.connect(func() -> void: view_diff_requested.emit(change_set))
		_buttons_bar.add_child(_diff_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons_bar.add_child(spacer)
	_reject_btn = Button.new()
	_reject_btn.text = AISidebarI18n.get_text("btn_reject")
	_reject_btn.theme_type_variation = AISidebarThemeBuilder.GHOST_BUTTON
	_reject_btn.pressed.connect(_on_reject)
	_buttons_bar.add_child(_reject_btn)
	_approve_btn = Button.new()
	_approve_btn.text = AISidebarI18n.get_text("btn_approve_delete") if _is_danger else AISidebarI18n.get_text("btn_approve")
	_approve_btn.theme_type_variation = AISidebarThemeBuilder.APPROVE_DANGER_BUTTON if _is_danger else AISidebarThemeBuilder.APPROVE_BUTTON
	AISidebarIconHelper.apply_tinted_icon(_approve_btn, "check", AISidebarTheme.emphasize(tone), AISidebarTheme.ICON_SIZE_SM)
	_approve_btn.pressed.connect(_on_approve)
	_buttons_bar.add_child(_approve_btn)

func _risk_text() -> String:
	match AISidebarPermissionPolicy.get_tool_risk(tool_name):
		AISidebarPermissionPolicy.RiskLevel.DESTRUCTIVE:
			return AISidebarI18n.get_text("approval_risk_delete")
		AISidebarPermissionPolicy.RiskLevel.WRITE:
			return AISidebarI18n.get_text("approval_risk_write")
		AISidebarPermissionPolicy.RiskLevel.EXTERNAL_SENSITIVE:
			return AISidebarI18n.get_text("approval_risk_persistent")
	return ""

func _verb_text() -> String:
	match tool_name:
		"delete_node":
			return AISidebarI18n.get_text("approval_verb_delete_node")
		"delete_file":
			return AISidebarI18n.get_text("approval_verb_delete_file")
		"create_or_update_script", "write_files":
			return AISidebarI18n.get_text("approval_verb_update_file")
		"replace_file_content":
			return AISidebarI18n.get_text("approval_verb_edit_file")
		"add_rule":
			if str(args.get("scope", "project")) == "global":
				return AISidebarI18n.get_text("approval_verb_add_rule_global")
			return AISidebarI18n.get_text("approval_verb_add_rule_project")
	return AISidebarI18n.get_text("approval_verb_tool", {"tool": tool_name})

func _target_text() -> String:
	if tool_name == "add_rule":
		return str(args.get("rule", ""))
	for key: String in ["file_path", "node_path", "scene_path", "path"]:
		var v := str(args.get(key, ""))
		if not v.is_empty():
			return v
	return ""

func _hint_text() -> String:
	match tool_name:
		"delete_file":
			return AISidebarI18n.get_text("approval_hint_delete_file")
		"delete_node":
			return AISidebarI18n.get_text("approval_hint_delete_node")
		"create_or_update_script", "replace_file_content", "write_files":
			return AISidebarI18n.get_text("approval_hint_edit")
		"add_rule":
			return AISidebarI18n.get_text("approval_hint_add_rule")
	return ""

func mark_approved() -> void:
	_resolve(AISidebarI18n.get_text("approval_approved"), "check", AISidebarTheme.COLOR_TONE_SUCCESS_TEXT)

func mark_rejected() -> void:
	_resolve(AISidebarI18n.get_text("approval_rejected"), "x", AISidebarTheme.COLOR_TONE_ERROR_TEXT)

## Sonuçlanmış kart sadeleşir: sonuç başlığı, fiil ve hedef kalır; ipucu ve düğmeler gider (Farkı gör kalır).
func _resolve(title: String, icon: String, color: Color) -> void:
	is_resolved = true
	theme_type_variation = AISidebarThemeBuilder.CARD_APPROVAL_DONE
	if _title_lbl:
		_title_lbl.text = title
		_title_lbl.theme_type_variation = AISidebarThemeBuilder.TITLE
		_title_lbl.add_theme_color_override("font_color", color)
	if _title_icon:
		AISidebarIconHelper.set_rect_icon(_title_icon, icon, color, AISidebarTheme.ICON_SIZE_MD)
	if _stripe:
		_stripe.color = Color(color, 0.6)
	if _chip:
		_chip.theme_type_variation = AISidebarThemeBuilder.ICON_CHIP_SUCCESS if icon == "check" else AISidebarThemeBuilder.ICON_CHIP_DANGER
	if _risk_badge:
		_risk_badge.visible = false
	if _hint_lbl:
		_hint_lbl.visible = false
	for b: Button in [_approve_btn, _reject_btn]:
		if b:
			b.disabled = true
			b.visible = false

func _on_approve() -> void:
	if is_resolved:
		return
	mark_approved()
	action_approved.emit()

func _on_reject() -> void:
	if is_resolved:
		return
	mark_rejected()
	action_rejected.emit()
