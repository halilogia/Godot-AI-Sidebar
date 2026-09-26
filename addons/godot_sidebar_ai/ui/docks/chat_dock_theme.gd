@tool
extends RefCounted

## ChatDock'un sahne düğümlerine görünüm verir (SRP: yalnızca görünüm). Temayı köke verir ve iskelet
## düğümlerine adlı tip varyasyonlarını atar; stil kutusu, yazı boyu ve renk tema üreticisindedir
## (AISidebarThemeBuilder). Mantık içermez; ChatDock `_ready` ve durum değişimlerinde çağırır.

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarMotion = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_motion.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")

static func apply(dock: Control) -> void:
	# 0. Tema: adlı tip varyasyonları bütün alt düğümlere geçer.
	dock.theme = AISidebarThemeBuilder.build(AISidebarThemeBuilder.Density.COMPACT)
	AISidebarMotion.enabled = AISidebarConfig.load_config().get("ui_animations", true) == true
	dock.theme_type_variation = AISidebarThemeBuilder.APP_PANEL

	# 1. Yerleşim boşlukları (ölçekli)
	for path: String in ["MainLayout", "MainLayout/HeaderBar", "MainLayout/ModelBar", "MainLayout/InputArea", "MainLayout/InputArea/ButtonsBar"]:
		if dock.has_node(path):
			var sep: int = AISidebarTheme.SPACE_SM if path == "MainLayout" else AISidebarTheme.SPACE_XS
			var box: Control = dock.get_node(path)
			box.add_theme_constant_override("separation", AISidebarTheme.px(sep))

	# 2. Başlık
	_variation(dock.title_label, AISidebarThemeBuilder.HEADER_TITLE)
	_variation(dock.status_badge, AISidebarThemeBuilder.STATUS_TEXT)
	for btn: Variant in [dock.new_chat_btn, dock.history_btn, dock.export_btn, dock.copy_task_btn]:
		_variation(btn, AISidebarThemeBuilder.HEADER_BUTTON)

	# 3. Model çubuğu (onay modu hapının rengi moda göre ModelBarController'da atanır)
	_variation(dock.model_selector, AISidebarThemeBuilder.SELECT)
	_variation(dock.approve_mode_btn, AISidebarThemeBuilder.PILL_BUTTON)
	for btn: Variant in [dock.refresh_models_btn, dock.settings_btn]:
		_variation(btn, AISidebarThemeBuilder.ICON_BUTTON)

	# 4. Akış ve bahsetme listesi
	var stream: Control = dock.message_stream
	if stream:
		stream.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	_variation(dock.mention_container, AISidebarThemeBuilder.POPUP_PANEL)
	_variation(dock.mention_list, AISidebarThemeBuilder.LIST)

	# 5. Giriş alanı
	_variation(dock.input_field, AISidebarThemeBuilder.TEXT_EDIT)
	_variation(dock.clear_btn, AISidebarThemeBuilder.HEADER_BUTTON)
	var jump: Button = dock.jump_to_bottom_btn
	if jump:
		jump.theme_type_variation = AISidebarThemeBuilder.FLOAT_BUTTON
		AISidebarIconHelper.apply_tinted_icon(jump, "arrow-down", AISidebarTheme.COLOR_TEXT_SECONDARY, AISidebarTheme.ICON_SIZE_SM)

	apply_send_button(dock.send_btn, dock.agent_runner != null and dock.agent_runner.is_running())

## Gönder düğmesi: çalışırken kırmızı Durdur, boştayken vurgu renginde Gönder.
static func apply_send_button(send_btn: Button, is_running: bool) -> void:
	if not send_btn:
		return
	send_btn.theme_type_variation = AISidebarThemeBuilder.STOP_BUTTON if is_running else AISidebarThemeBuilder.SEND_BUTTON

static func _variation(node: Variant, variation: String) -> void:
	if node is Control:
		var c: Control = node
		c.theme_type_variation = variation
