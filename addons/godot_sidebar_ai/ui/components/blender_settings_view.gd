@tool
extends VBoxContainer
class_name AISidebarBlenderSettingsView

## Ayarlar → Blender: sidebar ajanının Blender Copilot'u kullanmasını açar (3B model, prop, karakter, animasyon
## Blender'da yapılır, `.glb` olarak projeye gelir). Köprünün adresi ve token'ı Blender'daki eklenti panelinden
## kopyalanır. Değişiklikler hemen kaydedilir; "Bağlantıyı dene" Blender'a bir araç listesi isteği yollar.

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarBlenderClient = preload("res://addons/godot_sidebar_ai/core/bridge/blender_client.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarSettingsUi = preload("res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd")

var _badge: Label
var _enable: CheckBox
var _url: LineEdit
var _token: LineEdit
var _note: Label
var _loading := false

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_MD))

	_badge = AISidebarSettingsUi.badge("", AISidebarThemeBuilder.TONE_MUTED)
	var card := AISidebarSettingsUi.card(self, AISidebarI18n.get_text("blender_settings_title"), AISidebarI18n.get_text("blender_settings_hint"), _badge)
	_enable = CheckBox.new()
	_enable.text = AISidebarI18n.get_text("blender_settings_enable")
	_enable.toggled.connect(func(_on: bool) -> void: _save())
	card.add_child(_enable)
	_url = AISidebarSettingsUi.line_edit(AISidebarBlenderClient.DEFAULT_URL)
	_url.text_submitted.connect(func(_t: String) -> void: _save())
	_url.focus_exited.connect(_save)
	AISidebarSettingsUi.form_row(card, AISidebarI18n.get_text("blender_settings_url"), _url)
	_token = AISidebarSettingsUi.line_edit("")
	_token.secret = true
	_token.text_submitted.connect(func(_t: String) -> void: _save())
	_token.focus_exited.connect(_save)
	AISidebarSettingsUi.form_row(card, AISidebarI18n.get_text("blender_settings_token"), _token)
	var row := AISidebarSettingsUi.row(card)
	row.add_child(AISidebarSettingsUi.spacer())
	row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("blender_settings_test"), _on_test))
	row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("blender_settings_save"), _on_save))
	_note = AISidebarSettingsUi.status_label()
	card.add_child(_note)

	var how := AISidebarSettingsUi.card(self, AISidebarI18n.get_text("blender_settings_how_title"), AISidebarI18n.get_text("blender_settings_how"))
	how.add_child(AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("blender_settings_where")))

func refresh() -> void:
	var s := AISidebarBlenderClient.settings_from(AISidebarConfig.load_config())
	_loading = true
	_enable.button_pressed = s["enabled"] == true
	_url.text = str(s["url"])
	_token.text = str(s["token"])
	_loading = false
	_update_badge()
	AISidebarSettingsUi.set_status(_note, "")

func _update_badge() -> void:
	if _enable.button_pressed:
		AISidebarSettingsUi.set_badge(_badge, AISidebarI18n.get_text("blender_settings_badge_on"), AISidebarThemeBuilder.TONE_SUCCESS)
	else:
		AISidebarSettingsUi.set_badge(_badge, AISidebarI18n.get_text("blender_settings_badge_off"), AISidebarThemeBuilder.TONE_MUTED)

func _save() -> void:
	if _loading:
		return
	var cfg := AISidebarConfig.load_config()
	cfg["blender_bridge_enabled"] = _enable.button_pressed
	cfg["blender_bridge_url"] = _url.text.strip_edges()
	cfg["blender_bridge_token"] = _token.text.strip_edges()
	AISidebarConfig.save_config(cfg)
	_update_badge()

func _on_save() -> void:
	_save()
	AISidebarSettingsUi.set_status(_note, AISidebarI18n.get_text("blender_settings_saved"))

func _on_test() -> void:
	_save()
	AISidebarSettingsUi.set_status(_note, AISidebarI18n.get_text("blender_settings_testing"))
	var cfg := AISidebarBlenderClient.settings_from(AISidebarConfig.load_config())
	var reply: Dictionary = await AISidebarBlenderClient.request_async(cfg, "tools/list", {}, 10.0)
	if reply.get("ok", false) != true:
		AISidebarSettingsUi.set_status(_note, AISidebarI18n.get_text("blender_settings_test_failed", {"error": str(reply.get("error", ""))}), true)
		return
	var tools := AISidebarBlenderClient.summarize_tools(AISidebarBlenderClient.as_dict(reply.get("result", {})))
	AISidebarSettingsUi.set_status(_note, AISidebarI18n.get_text("blender_settings_test_ok", {"count": tools.size()}))
