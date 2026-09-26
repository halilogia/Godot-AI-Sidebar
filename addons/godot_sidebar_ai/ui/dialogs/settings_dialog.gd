@tool
extends AcceptDialog

## Ayarlar penceresi: sol menü + sayfa. Sayfalar kodla ve ortak bileşenlerle (AISidebarSettingsUi)
## kurulur; her açılışta yeniden kurulur, böylece dil ve editör yazı boyu değişiklikleri hemen görünür.
##   0 Sağlayıcı, 1 Model & Parametreler, 2 Genel (dil, görünüm, onaylar)  → AISidebarSettingsGeneralPages
##   3 Kurallar (bağlam yükü, yerleşik kurallar = sistem istemi, global / proje kuralları) → AISidebarRulesView
##   4 Skill'ler → AISidebarSkillsView
##   5 Dış Ajan (MCP) → AISidebarMcpSettingsView
## "Kaydet ve Kapat" config.json'a yazar ve settings_saved yayar. Skill aç / kapa, kural ekleme ve MCP
## köprüsü kendi eylemleriyle hemen uygulanır.

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarMotion = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_motion.gd")
const AISidebarSettingsUi = preload("res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd")
const AISidebarSettingsGeneralPages = preload("res://addons/godot_sidebar_ai/ui/components/settings_general_pages.gd")
const AISidebarRulesView = preload("res://addons/godot_sidebar_ai/ui/components/rules_view.gd")
const AISidebarSkillsView = preload("res://addons/godot_sidebar_ai/ui/components/skills_view.gd")
const AISidebarMcpSettingsView = preload("res://addons/godot_sidebar_ai/ui/components/mcp_settings_view.gd")

signal settings_saved()

const CATEGORY_RULES := 3
const CATEGORY_SKILLS := 4
const CATEGORY_MCP := 5
const BASE_SIZE := Vector2(920, 660)

var general: AISidebarSettingsGeneralPages
var rules_view: AISidebarRulesView
var skills_view: AISidebarSkillsView
var mcp_view: AISidebarMcpSettingsView

var _root: HBoxContainer
var _scroll: ScrollContainer
var _nav_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _active: int = 0

func _ready() -> void:
	if not confirmed.is_connected(_on_confirmed):
		confirmed.connect(_on_confirmed)

func open_settings() -> void:
	_build()
	var cfg: Dictionary = AISidebarConfig.load_config()
	general.load_from(cfg)
	rules_view.load_from(cfg)
	_select_category(0)
	# Editör yazı boyuyla büyür, ekranın (editör penceresinin) %90'ını aşmaz.
	var scale := maxf(1.0, AISidebarTheme.ui_scale)
	var avail := Vector2(get_tree().root.size) * 0.9
	popup_centered(Vector2i((BASE_SIZE * scale).min(avail)))

func _build() -> void:
	title = AISidebarI18n.get_text("settings_title")
	ok_button_text = AISidebarI18n.get_text("btn_save_close")
	theme = AISidebarSettingsUi.form_theme()
	get_ok_button().theme_type_variation = AISidebarThemeBuilder.PRIMARY_BUTTON
	if _root != null:
		_root.queue_free()
	_nav_buttons.clear()
	_pages.clear()

	_root = HBoxContainer.new()
	_root.name = "MainHBox"
	_root.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_MD))
	add_child(_root)

	var nav_panel := PanelContainer.new()
	nav_panel.custom_minimum_size = Vector2(float(AISidebarSettingsUi.base_size) * 13.0, 0)
	nav_panel.theme_type_variation = AISidebarThemeBuilder.CARD_INSET
	_root.add_child(nav_panel)
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_XXS))
	nav_panel.add_child(nav)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_scroll)
	# Sağ boşluk: kaydırma çubuğu kartların kenarına binmesin.
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", AISidebarTheme.px(AISidebarTheme.SPACE_MD))
	_scroll.add_child(gutter)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_child(pages)

	general = AISidebarSettingsGeneralPages.new()
	rules_view = AISidebarRulesView.new()
	skills_view = AISidebarSkillsView.new()
	mcp_view = AISidebarMcpSettingsView.new()
	var entries: Array = [
		["tab_provider", general.build_provider_page()],
		["tab_parameters", general.build_model_page()],
		["tab_appearance", general.build_language_page()],
		["tab_rules", rules_view],
		["tab_skills", skills_view],
		["tab_external_agent", mcp_view],
	]
	for e: Array in entries:
		var key: String = e[0]
		var page: Control = e[1]
		var idx := _pages.size()
		var btn := Button.new()
		btn.text = AISidebarI18n.get_text(key)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func() -> void: _select_category(idx))
		nav.add_child(btn)
		_nav_buttons.append(btn)
		page.visible = false
		pages.add_child(page)
		_pages.append(page)

func _select_category(idx: int) -> void:
	_active = idx
	for i in _pages.size():
		_pages[i].visible = i == idx
		if i == idx:
			AISidebarMotion.fade_in(_pages[i], AISidebarMotion.DURATION_FAST)
		AISidebarSettingsUi.style_nav_button(_nav_buttons[i], i == idx)
	if idx == CATEGORY_RULES:
		rules_view.refresh()
	elif idx == CATEGORY_SKILLS:
		skills_view.refresh()
	elif idx == CATEGORY_MCP:
		mcp_view.refresh()
	if _scroll != null:
		_scroll.scroll_vertical = 0

func _on_confirmed() -> void:
	if general == null:
		return
	var cfg: Dictionary = AISidebarConfig.load_config()
	general.write_to(cfg)
	cfg["system_prompt"] = rules_view.prompt_text()
	AISidebarI18n.set_language(general.selected_language())
	AISidebarConfig.save_config(cfg)
	settings_saved.emit()
