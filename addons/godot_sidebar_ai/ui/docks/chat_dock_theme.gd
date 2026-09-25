@tool
extends RefCounted

## ChatDock'un sahne düğümlerine tema/stil uygular (SRP: yalnızca görünüm).
## Mantık içermez; ChatDock `_ready` ve durum değişimlerinde çağırır.

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")

static func apply(dock: Control) -> void:
	# 1. Root PanelContainer & Background
	dock.add_theme_stylebox_override("panel", AISidebarTheme.create_app_bg_style())

	# 2. MainLayout & Container Gaps
	for path in ["MainLayout", "MainLayout/HeaderBar", "MainLayout/ModelBar", "MainLayout/InputArea", "MainLayout/InputArea/ButtonsBar"]:
		if dock.has_node(path):
			var sep = AISidebarTheme.SPACE_SM if path == "MainLayout" else AISidebarTheme.SPACE_XS
			dock.get_node(path).add_theme_constant_override("separation", sep)

	# 3. HeaderBar Typography & Buttons
	if dock.title_label:
		dock.title_label.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_HEADER)
		dock.title_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	if dock.status_badge:
		dock.status_badge.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	for btn in [dock.new_chat_btn, dock.history_btn, dock.export_btn, dock.copy_task_btn]:
		_style_ghost_text_button(btn, AISidebarTheme.FONT_SIZE_SMALL)

	# 4. ModelBar
	if dock.model_selector:
		dock.model_selector.add_theme_stylebox_override("normal", AISidebarTheme.create_input_style())
		dock.model_selector.add_theme_stylebox_override("hover", AISidebarTheme.create_card_hover_style())
		dock.model_selector.add_theme_stylebox_override("pressed", AISidebarTheme.create_card_active_style())
		dock.model_selector.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
		dock.model_selector.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	if dock.approve_mode_btn:
		dock.approve_mode_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XXS))
		dock.approve_mode_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_card_hover_style(AISidebarTheme.SPACE_XXS))
		dock.approve_mode_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	for btn in [dock.refresh_models_btn, dock.settings_btn]:
		_style_ghost_boxes(btn)

	# 5. Message Stream
	if dock.message_stream:
		dock.message_stream.add_theme_constant_override("separation", AISidebarTheme.SPACE_SM)

	# 6. Mention Popup
	if dock.mention_container:
		dock.mention_container.add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XS))
	if dock.mention_list:
		dock.mention_list.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)

	# 7. Input Area & Buttons
	if dock.input_field:
		dock.input_field.add_theme_stylebox_override("normal", AISidebarTheme.create_input_style())
		dock.input_field.add_theme_stylebox_override("focus", AISidebarTheme.create_input_focus_style())
		dock.input_field.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)
		dock.input_field.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
		dock.input_field.add_theme_color_override("font_placeholder_color", AISidebarTheme.COLOR_TEXT_MUTED)
	_style_ghost_text_button(dock.clear_btn, AISidebarTheme.FONT_SIZE_BODY)
	if dock.jump_to_bottom_btn:
		dock.jump_to_bottom_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XXS))
		dock.jump_to_bottom_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_card_hover_style(AISidebarTheme.SPACE_XXS))
		dock.jump_to_bottom_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		dock.jump_to_bottom_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
		AISidebarIconHelper.apply_tinted_icon(dock.jump_to_bottom_btn, "arrow-down", AISidebarTheme.COLOR_TEXT_SECONDARY, 12)

	apply_send_button(dock.send_btn, dock.agent_runner != null and dock.agent_runner.is_running())

## Send butonu: çalışırken kırmızı Stop, boştayken accent Send.
static func apply_send_button(send_btn: Button, is_running: bool) -> void:
	if not send_btn:
		return
	if is_running:
		var stop_normal = StyleBoxFlat.new()
		stop_normal.bg_color = AISidebarTheme.COLOR_ERROR
		stop_normal.set_corner_radius_all(AISidebarTheme.RADIUS_MD)
		stop_normal.content_margin_left = AISidebarTheme.SPACE_MD
		stop_normal.content_margin_right = AISidebarTheme.SPACE_MD
		stop_normal.content_margin_top = AISidebarTheme.SPACE_XS + 1
		stop_normal.content_margin_bottom = AISidebarTheme.SPACE_XS + 1
		var stop_hover = stop_normal.duplicate()
		stop_hover.bg_color = AISidebarTheme.COLOR_ERROR_HOVER
		send_btn.add_theme_stylebox_override("normal", stop_normal)
		send_btn.add_theme_stylebox_override("hover", stop_hover)
		send_btn.add_theme_stylebox_override("pressed", stop_normal)
	else:
		send_btn.add_theme_stylebox_override("normal", AISidebarTheme.create_accent_button_style(false, false))
		send_btn.add_theme_stylebox_override("hover", AISidebarTheme.create_accent_button_style(true, false))
		send_btn.add_theme_stylebox_override("pressed", AISidebarTheme.create_accent_button_style(false, true))
	send_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_WHITE)
	send_btn.add_theme_color_override("icon_normal_color", Color.WHITE)
	send_btn.add_theme_color_override("icon_hover_color", Color.WHITE)
	send_btn.add_theme_color_override("icon_pressed_color", Color.WHITE)
	send_btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_BODY)

static func _style_ghost_boxes(btn: Button) -> void:
	if not btn:
		return
	btn.add_theme_stylebox_override("normal", AISidebarTheme.create_ghost_button_style(false))
	btn.add_theme_stylebox_override("hover", AISidebarTheme.create_ghost_button_style(true))
	btn.add_theme_stylebox_override("pressed", AISidebarTheme.create_ghost_button_style(true))

static func _style_ghost_text_button(btn: Button, font_size: int) -> void:
	if not btn:
		return
	_style_ghost_boxes(btn)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
	btn.add_theme_color_override("font_hover_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
