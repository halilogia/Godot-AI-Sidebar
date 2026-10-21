@tool
extends VBoxContainer
class_name AISidebarDevlogSettingsView

## Ayarlar → Devlog: sürüm etiketi (git tag v...) atılınca oyunun devlog klibini kendiliğinden çeken git kancasını açar /
## kapatır. Durum config'te değil kancanın kendisinde tutulur (projenin .git/hooks klasörü), böylece sayfa her zaman
## gerçeği gösterir. Kanca, projenin tools/devlog/clips.json manifestindeki yeni özellik kliplerini çeker.

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarSettingsUi = preload("res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd")
const GameCapture = preload("res://addons/godot_sidebar_ai/core/capture/game_capture.gd")

var _badge: Label
var _enable: CheckBox
var _note: Label
var _loading := false

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_MD))

	_badge = AISidebarSettingsUi.badge("", AISidebarThemeBuilder.TONE_MUTED)
	var card := AISidebarSettingsUi.card(self, AISidebarI18n.get_text("devlog_settings_title"), AISidebarI18n.get_text("devlog_settings_hint"), _badge)
	_enable = CheckBox.new()
	_enable.text = AISidebarI18n.get_text("devlog_settings_enable")
	_enable.toggled.connect(_on_toggled)
	card.add_child(_enable)
	_note = AISidebarSettingsUi.status_label()
	card.add_child(_note)

	var how := AISidebarSettingsUi.card(self, AISidebarI18n.get_text("devlog_settings_how_title"), AISidebarI18n.get_text("devlog_settings_how"))
	how.add_child(AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("devlog_settings_where")))

func refresh() -> void:
	_loading = true
	_enable.button_pressed = GameCapture.hook_installed(GameCapture.project_dir())
	_loading = false
	_update_badge()
	AISidebarSettingsUi.set_status(_note, "")

func _update_badge() -> void:
	if _enable.button_pressed:
		AISidebarSettingsUi.set_badge(_badge, AISidebarI18n.get_text("devlog_settings_badge_on"), AISidebarThemeBuilder.TONE_SUCCESS)
	else:
		AISidebarSettingsUi.set_badge(_badge, AISidebarI18n.get_text("devlog_settings_badge_off"), AISidebarThemeBuilder.TONE_MUTED)

func _on_toggled(on: bool) -> void:
	if _loading:
		return
	var proj := GameCapture.project_dir()
	if not on:
		GameCapture.remove_release_hook(proj)
		AISidebarSettingsUi.set_status(_note, AISidebarI18n.get_text("devlog_settings_removed"))
		_update_badge()
		return
	var err := GameCapture.install_release_hook(proj, OS.get_executable_path())
	if err != "":
		_loading = true
		_enable.button_pressed = false
		_loading = false
		var key := "devlog_settings_err_no_git" if err == "no_git" else ("devlog_settings_err_foreign" if err == "foreign_hook" else "devlog_settings_err_write")
		AISidebarSettingsUi.set_status(_note, AISidebarI18n.get_text(key), true)
	elif not GameCapture.has_manifest(proj):
		AISidebarSettingsUi.set_status(_note, AISidebarI18n.get_text("devlog_settings_installed_no_manifest"))
	else:
		AISidebarSettingsUi.set_status(_note, AISidebarI18n.get_text("devlog_settings_installed"))
	_update_badge()
