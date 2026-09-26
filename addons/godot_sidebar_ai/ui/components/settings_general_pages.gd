@tool
extends RefCounted
class_name AISidebarSettingsGeneralPages

## Ayarlar penceresinin genel sayfaları (kodla, AISidebarSettingsUi ile kurulur):
##   Sağlayıcı: sağlayıcı seçimi, uç nokta (base_url, api_key), gelişmiş (stream, vision_capable)
##   Model & Parametreler: temperature, max_agent_steps (max_iterations aynı denetim)
##   Genel: language, ui_animations, auto_approve_mode, require_delete_approval, require_overwrite_approval
## Pencere açılırken config'ten yüklenir (load_from), "Kaydet ve Kapat"ta config'e yazılır (write_to).

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarMotion = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_motion.gd")
const AISidebarSettingsUi = preload("res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd")

const DEFAULT_TEMPERATURE := 0.20
const PROVIDERS: Array[String] = ["antigravity_cli", "openai_compatible"]
const LANGUAGES: Array[String] = ["tr", "en"]
const MODES: Array[String] = ["MANUAL", "AUTO", "FULL_AUTO"]

var provider_opt: OptionButton
var provider_hint: Label
var endpoint_box: VBoxContainer
var base_url_edit: LineEdit
var api_key_edit: LineEdit
var stream_check: CheckBox
var vision_opt: OptionButton
var temp_slider: HSlider
var temp_badge: Label
var steps_spin: SpinBox
var lang_opt: OptionButton
var mode_opt: OptionButton
var delete_check: CheckBox
var overwrite_check: CheckBox
var animations_check: CheckBox

func build_provider_page() -> VBoxContainer:
	var page := AISidebarSettingsUi.page()
	var prov := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_provider"))
	provider_opt = AISidebarSettingsUi.option_button()
	provider_opt.add_item(AISidebarI18n.get_text("provider_antigravity"), 0)
	provider_opt.add_item(AISidebarI18n.get_text("provider_openai"), 1)
	provider_opt.item_selected.connect(func(_i: int) -> void: _apply_provider_state())
	prov.add_child(provider_opt)
	provider_hint = AISidebarSettingsUi.hint_label("")
	prov.add_child(provider_hint)

	endpoint_box = AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_endpoint"), AISidebarI18n.get_text("settings_endpoint_hint"))
	base_url_edit = AISidebarSettingsUi.line_edit("http://127.0.0.1:20128/v1")
	base_url_edit.name = "BaseUrlEdit"
	AISidebarSettingsUi.form_row(endpoint_box, AISidebarI18n.get_text("settings_base_url"), base_url_edit)
	api_key_edit = AISidebarSettingsUi.line_edit(AISidebarI18n.get_text("settings_api_key_placeholder"))
	api_key_edit.secret = true
	AISidebarSettingsUi.form_row(endpoint_box, AISidebarI18n.get_text("settings_api_key"), api_key_edit)

	var adv := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_advanced_title"))
	stream_check = CheckBox.new()
	stream_check.text = AISidebarI18n.get_text("settings_stream")
	adv.add_child(stream_check)
	adv.add_child(AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("settings_stream_hint")))
	vision_opt = AISidebarSettingsUi.option_button()
	vision_opt.add_item(AISidebarI18n.get_text("settings_vision_auto"), 0)
	vision_opt.add_item(AISidebarI18n.get_text("settings_vision_on"), 1)
	vision_opt.add_item(AISidebarI18n.get_text("settings_vision_off"), 2)
	AISidebarSettingsUi.form_row(adv, AISidebarI18n.get_text("settings_vision"), vision_opt)
	adv.add_child(AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("settings_vision_hint")))
	return page

func build_model_page() -> VBoxContainer:
	var page := AISidebarSettingsUi.page()
	temp_badge = AISidebarSettingsUi.badge("", AISidebarTheme.COLOR_SUCCESS)
	var temp := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_temperature"), AISidebarI18n.get_text("hint_temperature"), temp_badge)
	temp_slider = HSlider.new()
	temp_slider.max_value = 2.0
	temp_slider.step = 0.05
	temp_slider.scrollable = false
	temp_slider.value_changed.connect(_on_temp_changed)
	temp.add_child(temp_slider)
	var reset_row := AISidebarSettingsUi.row(temp)
	reset_row.add_child(AISidebarSettingsUi.spacer())
	reset_row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("btn_reset_temp_to"), func() -> void: temp_slider.value = DEFAULT_TEMPERATURE))

	var steps := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_max_steps"), AISidebarI18n.get_text("hint_max_steps"))
	steps_spin = SpinBox.new()
	steps_spin.min_value = 1
	steps_spin.max_value = 50
	steps_spin.step = 1
	var steps_row := AISidebarSettingsUi.row(steps)
	steps_row.add_child(steps_spin)
	return page

func build_language_page() -> VBoxContainer:
	var page := AISidebarSettingsUi.page()
	var lang := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_language"), AISidebarI18n.get_text("hint_language"))
	lang_opt = AISidebarSettingsUi.option_button()
	lang_opt.add_item("Türkçe (TR)", 0)  # i18n-ignore: dil adı kendi dilinde yazılır
	lang_opt.add_item("English (EN)", 1)  # i18n-ignore: dil adı kendi dilinde yazılır
	lang.add_child(lang_opt)

	var look := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_appearance"))
	animations_check = CheckBox.new()
	animations_check.text = AISidebarI18n.get_text("settings_ui_animations")
	look.add_child(animations_check)
	look.add_child(AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("settings_ui_animations_hint")))

	var appr := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_approval"), AISidebarI18n.get_text("hint_approval_mode"))
	mode_opt = AISidebarSettingsUi.option_button()
	for mode: String in MODES:
		var key := "mode_" + mode.to_lower()
		mode_opt.add_item("%s: %s" % [AISidebarI18n.get_text(key), AISidebarI18n.get_text(key + "_desc")])
	appr.add_child(mode_opt)
	delete_check = CheckBox.new()
	delete_check.text = AISidebarI18n.get_text("settings_require_delete")
	appr.add_child(delete_check)
	overwrite_check = CheckBox.new()
	overwrite_check.text = AISidebarI18n.get_text("settings_require_overwrite")
	appr.add_child(overwrite_check)
	appr.add_child(AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("settings_approvals_hint")))
	return page

func load_from(cfg: Dictionary) -> void:
	provider_opt.selected = maxi(0, PROVIDERS.find(str(cfg.get("provider_type", PROVIDERS[0]))))
	_apply_provider_state()
	base_url_edit.text = str(cfg.get("base_url", ""))
	api_key_edit.text = str(cfg.get("api_key", ""))
	stream_check.button_pressed = cfg.get("stream", true) == true
	var vision: Variant = cfg.get("vision_capable", null)
	if not (vision is bool):
		vision_opt.selected = 0
	elif vision == true:
		vision_opt.selected = 1
	else:
		vision_opt.selected = 2
	var temperature: float = cfg.get("temperature", DEFAULT_TEMPERATURE)
	temp_slider.value = temperature
	_on_temp_changed(temp_slider.value)
	var steps: float = cfg.get("max_agent_steps", cfg.get("max_iterations", 20))
	steps_spin.value = steps
	lang_opt.selected = maxi(0, LANGUAGES.find(str(cfg.get("language", "tr"))))
	animations_check.button_pressed = cfg.get("ui_animations", true) == true
	mode_opt.selected = maxi(0, MODES.find(str(cfg.get("auto_approve_mode", "MANUAL"))))
	delete_check.button_pressed = cfg.get("require_delete_approval", true) == true
	overwrite_check.button_pressed = cfg.get("require_overwrite_approval", true) == true

func write_to(cfg: Dictionary) -> void:
	cfg["provider_type"] = PROVIDERS[provider_opt.selected]
	cfg["base_url"] = base_url_edit.text.strip_edges()
	cfg["api_key"] = api_key_edit.text.strip_edges()
	cfg["stream"] = stream_check.button_pressed
	cfg["vision_capable"] = null if vision_opt.selected == 0 else (vision_opt.selected == 1)
	cfg["temperature"] = snappedf(temp_slider.value, 0.05)
	var steps := int(steps_spin.value)
	cfg["max_agent_steps"] = steps
	cfg["max_iterations"] = steps
	cfg["language"] = LANGUAGES[lang_opt.selected]
	cfg["ui_animations"] = animations_check.button_pressed
	AISidebarMotion.enabled = animations_check.button_pressed
	cfg["auto_approve_mode"] = MODES[mode_opt.selected]
	cfg["require_delete_approval"] = delete_check.button_pressed
	cfg["require_overwrite_approval"] = overwrite_check.button_pressed

func selected_language() -> String:
	return LANGUAGES[lang_opt.selected]

func _apply_provider_state() -> void:
	var is_cli := provider_opt.selected == 0
	if is_cli:
		provider_hint.text = AISidebarI18n.get_text("hint_provider_agy")
		provider_hint.add_theme_color_override("font_color", AISidebarTheme.COLOR_SUCCESS)
	else:
		provider_hint.text = AISidebarI18n.get_text("hint_provider_openai")
		provider_hint.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
	base_url_edit.editable = not is_cli
	api_key_edit.editable = not is_cli
	var card := endpoint_box.get_parent() as Control
	card.modulate = AISidebarTheme.MODULATE_DISABLED if is_cli else AISidebarTheme.COLOR_WHITE

func _on_temp_changed(val: float) -> void:
	var v := snappedf(val, 0.05)
	var text := "%0.2f" % v
	if is_equal_approx(v, DEFAULT_TEMPERATURE):
		AISidebarSettingsUi.set_badge(temp_badge, AISidebarI18n.get_text("temp_value_default", {"value": text}), AISidebarTheme.COLOR_SUCCESS)
	elif v > 0.60:
		AISidebarSettingsUi.set_badge(temp_badge, AISidebarI18n.get_text("temp_value_high", {"value": text}), AISidebarTheme.COLOR_WARNING)
	else:
		AISidebarSettingsUi.set_badge(temp_badge, text, AISidebarTheme.COLOR_ACCENT)
