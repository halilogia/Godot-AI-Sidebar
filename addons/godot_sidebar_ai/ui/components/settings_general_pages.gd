@tool
extends RefCounted
class_name AISidebarSettingsGeneralPages

## Ayarlar penceresinin genel sayfaları (kodla, AISidebarSettingsUi ile kurulur):
##   Sağlayıcı: profiller (provider_profiles: yan yana kayıtlı sağlayıcılar; kaydederken gösterilen profil
##          etkin olur), sağlayıcı seçimi, uç nokta (base_url, api_key), gelişmiş (stream, vision_capable, report_usage)
##   Model & Parametreler: temperature, goal_max_rounds (/goal),
##          context_window (bağlam penceresi; 0 = sağlayıcının model listesinden)
##   Genel: language, ui_animations, auto_approve_mode, require_delete_approval, require_overwrite_approval,
##          hata bildirme (Hata bildir düğmesi; ayar değil, pencereyi açar)
## Pencere açılırken config'ten yüklenir (load_from), "Kaydet ve Kapat"ta config'e yazılır (write_to).

const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarGoalSession = preload("res://addons/godot_sidebar_ai/core/agent/goal_session.gd")
const AISidebarMotion = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_motion.gd")
const AISidebarSettingsUi = preload("res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

const DEFAULT_TEMPERATURE := 0.20
## Sağlayıcı şablonları (ad, adres): profil ekleyince adresi doğru doldurur. Özel adres yazmak yine serbest.
const PRESETS: Array = [
	["9Router", "http://localhost:20128/v1"],
	["OpenRouter", "https://openrouter.ai/api/v1"],
	["OpenCode Zen", "https://opencode.ai/zen/v1"],
	["OpenAI", "https://api.openai.com/v1"],
	["Ollama", "http://localhost:11434/v1"],
	["LM Studio", "http://localhost:1234/v1"],
]
const PROVIDERS: Array[String] = ["antigravity_cli", "openai_compatible"]
const EFFORTS: Array[String] = ["", "low", "medium", "high"]
const LANGUAGES: Array[String] = ["tr", "en"]
const MODES: Array[String] = ["MANUAL", "AUTO", "FULL_AUTO"]

var profile_opt: OptionButton
var profile_name_edit: LineEdit
var preset_opt: OptionButton
var profile_delete_btn: Button
## Pencerede düzenlenen profillerin kopyası ve formda gösterilen profil.
var _profiles: Array[Dictionary] = []
var _shown: int = 0
var provider_opt: OptionButton
var provider_hint: Label
var endpoint_box: VBoxContainer
var base_url_edit: LineEdit
var api_key_edit: LineEdit
var stream_check: CheckBox
var vision_opt: OptionButton
var usage_check: CheckBox
var effort_opt: OptionButton
var context_spin: SpinBox
var temp_slider: HSlider
var temp_badge: Label
var goal_rounds_spin: SpinBox
var lang_opt: OptionButton
var mode_opt: OptionButton
var delete_check: CheckBox
var overwrite_check: CheckBox
var animations_check: CheckBox
var notifications_check: CheckBox
var sound_check: CheckBox
var planning_check: CheckBox
## Genel sayfasındaki "Hata bildir" düğmesi (Ayarlar penceresi bağlar).
var on_bug_report: Callable = func() -> void: pass

func build_provider_page() -> VBoxContainer:
	var page := AISidebarSettingsUi.page()
	var profs := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_profiles"), AISidebarI18n.get_text("settings_profiles_hint"))
	var prof_row := AISidebarSettingsUi.row(profs)
	profile_opt = AISidebarSettingsUi.option_button()
	profile_opt.name = "ProfileOpt"
	profile_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_opt.item_selected.connect(_on_profile_selected)
	prof_row.add_child(profile_opt)
	prof_row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("btn_profile_add"), _on_profile_add))
	profile_delete_btn = AISidebarSettingsUi.button(AISidebarI18n.get_text("btn_profile_delete"), _on_profile_delete)
	prof_row.add_child(profile_delete_btn)
	profile_name_edit = AISidebarSettingsUi.line_edit()
	profile_name_edit.text_changed.connect(func(t: String) -> void: profile_opt.set_item_text(_shown, t if not t.strip_edges().is_empty() else "?"))
	AISidebarSettingsUi.form_row(profs, AISidebarI18n.get_text("settings_profile_name"), profile_name_edit)
	preset_opt = AISidebarSettingsUi.option_button()
	preset_opt.add_item(AISidebarI18n.get_text("settings_profile_preset_pick"))
	for preset: Array in PRESETS:
		preset_opt.add_item(str(preset[0]))  # i18n-ignore: hizmet adı
	preset_opt.item_selected.connect(_on_preset_selected)
	AISidebarSettingsUi.form_row(profs, AISidebarI18n.get_text("settings_profile_preset"), preset_opt)

	var prov := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_provider"))
	provider_opt = AISidebarSettingsUi.option_button()
	provider_opt.add_item(AISidebarI18n.get_text("provider_antigravity"), 0)
	provider_opt.add_item(AISidebarI18n.get_text("provider_openai"), 1)
	provider_opt.item_selected.connect(func(_i: int) -> void: _apply_provider_state())
	prov.add_child(provider_opt)
	provider_hint = AISidebarSettingsUi.hint_label("")
	prov.add_child(provider_hint)

	endpoint_box = AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_endpoint"), AISidebarI18n.get_text("settings_endpoint_hint"))
	base_url_edit = AISidebarSettingsUi.line_edit("https://openrouter.ai/api/v1")
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
	effort_opt = AISidebarSettingsUi.option_button()
	for key: String in ["settings_effort_auto", "settings_effort_low", "settings_effort_medium", "settings_effort_high"]:
		effort_opt.add_item(AISidebarI18n.get_text(key))
	AISidebarSettingsUi.form_row(adv, AISidebarI18n.get_text("settings_effort"), effort_opt)
	adv.add_child(AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("settings_effort_hint")))
	usage_check = CheckBox.new()
	usage_check.text = AISidebarI18n.get_text("settings_report_usage")
	adv.add_child(usage_check)
	adv.add_child(AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("settings_report_usage_hint")))
	return page

func build_model_page() -> VBoxContainer:
	var page := AISidebarSettingsUi.page()
	temp_badge = AISidebarSettingsUi.badge("", AISidebarThemeBuilder.TONE_SUCCESS)
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

	var goal := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_goal"), AISidebarI18n.get_text("settings_goal_hint"))
	goal_rounds_spin = SpinBox.new()
	goal_rounds_spin.min_value = 1
	goal_rounds_spin.max_value = AISidebarGoalSession.MAX_ROUNDS_LIMIT
	goal_rounds_spin.step = 1
	AISidebarSettingsUi.form_row(goal, AISidebarI18n.get_text("settings_goal_max_rounds"), goal_rounds_spin)
	goal_rounds_spin.size_flags_horizontal = Control.SIZE_FILL

	var ctx := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_context"), AISidebarI18n.get_text("settings_context_hint"))
	context_spin = SpinBox.new()
	context_spin.min_value = 0
	context_spin.max_value = 10000000
	context_spin.step = 1000
	AISidebarSettingsUi.form_row(ctx, AISidebarI18n.get_text("settings_context_window"), context_spin)
	context_spin.size_flags_horizontal = Control.SIZE_FILL
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
	notifications_check = CheckBox.new()
	notifications_check.text = AISidebarI18n.get_text("settings_notifications")
	look.add_child(notifications_check)
	sound_check = CheckBox.new()
	sound_check.text = AISidebarI18n.get_text("settings_notification_sound")
	look.add_child(sound_check)
	look.add_child(AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("settings_notifications_hint")))

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

	var plan := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("settings_card_planning"), AISidebarI18n.get_text("settings_planning_hint"))
	planning_check = CheckBox.new()
	planning_check.text = AISidebarI18n.get_text("settings_planning_mode")
	plan.add_child(planning_check)

	var bug := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("bug_card_title"), AISidebarI18n.get_text("bug_card_hint"))
	var bug_row := AISidebarSettingsUi.row(bug)
	bug_row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("bug_open"), func() -> void: on_bug_report.call()))
	bug_row.add_child(AISidebarSettingsUi.spacer())
	return page

func load_from(cfg: Dictionary) -> void:
	AISidebarConfig.sync_active_profile(cfg)
	_profiles.clear()
	for prof: Dictionary in AISidebarConfig.profiles(cfg):
		_profiles.append(prof.duplicate(true))
	if _profiles.is_empty():
		var first := AISidebarConfig.profile_from(cfg)
		first["id"] = "default"
		first["name"] = AISidebarConfig._name_from_url(str(cfg.get("base_url", "")))
		_profiles.append(first)
	_shown = 0
	for i in _profiles.size():
		if str(_profiles[i].get("id", "")) == str(cfg.get("active_provider_id", "")):
			_shown = i
	_fill_profile_opt()
	_load_profile(_profiles[_shown])
	var temperature: float = cfg.get("temperature", DEFAULT_TEMPERATURE)
	temp_slider.value = temperature
	_on_temp_changed(temp_slider.value)
	var goal_rounds: float = cfg.get("goal_max_rounds", AISidebarGoalSession.DEFAULT_MAX_ROUNDS)
	goal_rounds_spin.value = goal_rounds
	lang_opt.selected = maxi(0, LANGUAGES.find(str(cfg.get("language", "tr"))))
	animations_check.button_pressed = cfg.get("ui_animations", true) == true
	notifications_check.button_pressed = cfg.get("notifications", true) == true
	sound_check.button_pressed = cfg.get("notification_sound", false) == true
	planning_check.button_pressed = cfg.get("planning_mode", false) == true
	mode_opt.selected = maxi(0, MODES.find(str(cfg.get("auto_approve_mode", "MANUAL"))))
	delete_check.button_pressed = cfg.get("require_delete_approval", true) == true
	overwrite_check.button_pressed = cfg.get("require_overwrite_approval", true) == true

func write_to(cfg: Dictionary) -> void:
	# Profiller yazılır; kaydederken formda gösterilen profil etkin olur ve değerleri düz anahtarlara geçer.
	_store_profile(_profiles[_shown])
	var saved: Array = []
	for prof: Dictionary in _profiles:
		saved.append(prof.duplicate(true))
	cfg["provider_profiles"] = saved
	cfg["active_provider_id"] = ""
	AISidebarConfig.activate_profile(cfg, str(_profiles[_shown].get("id", "")))
	cfg["temperature"] = snappedf(temp_slider.value, 0.05)
	cfg["goal_max_rounds"] = int(goal_rounds_spin.value)
	cfg["language"] = LANGUAGES[lang_opt.selected]
	cfg["ui_animations"] = animations_check.button_pressed
	cfg["notifications"] = notifications_check.button_pressed
	cfg["notification_sound"] = sound_check.button_pressed
	cfg["planning_mode"] = planning_check.button_pressed
	AISidebarMotion.enabled = animations_check.button_pressed
	cfg["auto_approve_mode"] = MODES[mode_opt.selected]
	cfg["require_delete_approval"] = delete_check.button_pressed
	cfg["require_overwrite_approval"] = overwrite_check.button_pressed

## Formdaki sağlayıcı alanları → profil (ve tersi).
func _store_profile(prof: Dictionary) -> void:
	prof["name"] = profile_name_edit.text.strip_edges()
	prof["provider_type"] = PROVIDERS[provider_opt.selected]
	prof["base_url"] = base_url_edit.text.strip_edges()
	prof["api_key"] = api_key_edit.text.strip_edges()
	prof["stream"] = stream_check.button_pressed
	prof["report_usage"] = usage_check.button_pressed
	prof["reasoning_effort"] = EFFORTS[effort_opt.selected]
	prof["context_window"] = int(context_spin.value)
	prof["vision_capable"] = null if vision_opt.selected == 0 else (vision_opt.selected == 1)

func _load_profile(prof: Dictionary) -> void:
	profile_name_edit.text = str(prof.get("name", ""))
	provider_opt.selected = maxi(0, PROVIDERS.find(str(prof.get("provider_type", "openai_compatible"))))
	_apply_provider_state()
	base_url_edit.text = str(prof.get("base_url", ""))
	api_key_edit.text = str(prof.get("api_key", ""))
	stream_check.button_pressed = prof.get("stream", true) == true
	usage_check.button_pressed = prof.get("report_usage", true) == true
	effort_opt.selected = maxi(0, EFFORTS.find(str(prof.get("reasoning_effort", ""))))
	var window: float = prof.get("context_window", 0)
	context_spin.value = window
	var vision: Variant = prof.get("vision_capable", null)
	if not (vision is bool):
		vision_opt.selected = 0
	elif vision == true:
		vision_opt.selected = 1
	else:
		vision_opt.selected = 2

func _fill_profile_opt() -> void:
	profile_opt.clear()
	for prof: Dictionary in _profiles:
		profile_opt.add_item(str(prof.get("name", "?")))
	profile_opt.selected = _shown
	profile_delete_btn.disabled = _profiles.size() < 2

func _on_profile_selected(index: int) -> void:
	_store_profile(_profiles[_shown])
	_shown = index
	_load_profile(_profiles[_shown])

func _on_profile_add() -> void:
	_store_profile(_profiles[_shown])
	var prof := AISidebarConfig.profile_from({})
	prof["id"] = "p%d" % Time.get_ticks_usec()
	prof["name"] = AISidebarI18n.get_text("settings_profile_new_name")
	prof["base_url"] = ""
	_profiles.append(prof)
	_shown = _profiles.size() - 1
	_fill_profile_opt()
	_load_profile(prof)
	if profile_name_edit.is_inside_tree():
		profile_name_edit.grab_focus()

## Şablon seçilince adres doldurulur; ad boşsa ya da varsayılan yeni ad ise şablon adı olur.
func _on_preset_selected(index: int) -> void:
	if index <= 0 or index > PRESETS.size():
		return
	var preset: Array = PRESETS[index - 1]
	base_url_edit.text = str(preset[1])
	var current := profile_name_edit.text.strip_edges()
	if current.is_empty() or current == AISidebarI18n.get_text("settings_profile_new_name"):
		profile_name_edit.text = str(preset[0])
		profile_name_edit.text_changed.emit(profile_name_edit.text)
	preset_opt.selected = 0

func _on_profile_delete() -> void:
	if _profiles.size() < 2:
		return
	_profiles.remove_at(_shown)
	_shown = 0
	_fill_profile_opt()
	_load_profile(_profiles[_shown])

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
		AISidebarSettingsUi.set_badge(temp_badge, AISidebarI18n.get_text("temp_value_default", {"value": text}), AISidebarThemeBuilder.TONE_SUCCESS)
	elif v > 0.60:
		AISidebarSettingsUi.set_badge(temp_badge, AISidebarI18n.get_text("temp_value_high", {"value": text}), AISidebarThemeBuilder.TONE_WARNING)
	else:
		AISidebarSettingsUi.set_badge(temp_badge, text, AISidebarThemeBuilder.TONE_ACCENT)
