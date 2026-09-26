@tool
extends VBoxContainer
class_name AISidebarMcpSettingsView

## Ayarlar → Dış Ajan (MCP): köprünün durumu, aç / kapa, port, Claude Code bağlantı komutunu panoya
## kopyalama. /mcp komutuyla aynı kontrol yüzeyini (AISidebarMcpBridgeControl) kullanır. Token
## arayüzde yalnız ilk 4 karakteriyle görünür; tamamı yalnız panoya gider.

const AISidebarMcpBridgeControl = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_bridge_control.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarSettingsUi = preload("res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd")

var _badge: Label
var _status: Label
var _toggle_btn: Button
var _connect_card: Control
var _command: Label
var _note: Label
var _port: SpinBox
var _port_row: Control

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", AISidebarTheme.SPACE_MD)

	_badge = AISidebarSettingsUi.badge("", AISidebarTheme.COLOR_TEXT_MUTED)
	var bridge_card := AISidebarSettingsUi.card(self, AISidebarI18n.get_text("mcp_settings_title"), AISidebarI18n.get_text("mcp_settings_hint"), _badge)
	var row := AISidebarSettingsUi.row(bridge_card)
	_status = AISidebarSettingsUi.body_label("")
	row.add_child(_status)
	_toggle_btn = AISidebarSettingsUi.primary_button("", _on_toggle)
	row.add_child(_toggle_btn)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.step = 1
	var port_row := AISidebarSettingsUi.form_row(bridge_card, AISidebarI18n.get_text("mcp_settings_port"), _port)
	_port_row = port_row
	_port.size_flags_horizontal = Control.SIZE_FILL
	port_row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("mcp_settings_apply_port"), _on_apply_port))
	_note = AISidebarSettingsUi.status_label()
	bridge_card.add_child(_note)

	var connect := AISidebarSettingsUi.card(self, AISidebarI18n.get_text("mcp_settings_connect_title"), AISidebarI18n.get_text("mcp_settings_connect_hint"))
	_connect_card = connect.get_parent() as Control
	_command = AISidebarSettingsUi.hint_label("")
	_command.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_command.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	_command.add_theme_stylebox_override("normal", AISidebarTheme.create_input_style())
	connect.add_child(_command)
	var copy_row := AISidebarSettingsUi.row(connect)
	copy_row.add_child(AISidebarSettingsUi.spacer())
	copy_row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("mcp_settings_copy"), _on_copy))

func refresh() -> void:
	var bridge := AISidebarMcpBridgeControl.instance
	AISidebarSettingsUi.set_status(_note, "")
	if bridge == null:
		AISidebarSettingsUi.set_badge(_badge, AISidebarI18n.get_text("mcp_settings_badge_off"), AISidebarTheme.COLOR_TEXT_MUTED)
		_status.text = AISidebarI18n.get_text("mcp_settings_unavailable")
		_toggle_btn.visible = false
		_port_row.visible = false
		_connect_card.visible = false
		return
	_toggle_btn.visible = true
	_port_row.visible = true
	_port.value = bridge.saved_port()
	var running := bridge.is_running()
	_connect_card.visible = running
	if running:
		AISidebarSettingsUi.set_badge(_badge, AISidebarI18n.get_text("mcp_settings_badge_on"), AISidebarTheme.COLOR_SUCCESS)
		_status.text = AISidebarI18n.get_text("mcp_settings_on", {"endpoint": bridge.endpoint(), "count": bridge.tool_count()})
		_toggle_btn.text = AISidebarI18n.get_text("mcp_settings_turn_off")
		_command.text = bridge.masked_claude_add_command()
	else:
		AISidebarSettingsUi.set_badge(_badge, AISidebarI18n.get_text("mcp_settings_badge_off"), AISidebarTheme.COLOR_TEXT_MUTED)
		_status.text = AISidebarI18n.get_text("mcp_settings_off")
		_toggle_btn.text = AISidebarI18n.get_text("mcp_settings_turn_on")
		_command.text = ""

func _on_toggle() -> void:
	var bridge := AISidebarMcpBridgeControl.instance
	if bridge == null:
		return
	if bridge.is_running():
		bridge.disable()
		refresh()
		return
	var res := bridge.enable()
	refresh()
	if res["ok"] != true:
		AISidebarSettingsUi.set_status(_note, AISidebarI18n.get_text("mcp_settings_start_failed", {"port": res["port"], "error": res["error"]}), true)

func _on_apply_port() -> void:
	var bridge := AISidebarMcpBridgeControl.instance
	if bridge == null:
		return
	var res := bridge.change_port(int(_port.value))
	refresh()
	if res["ok"] != true:
		AISidebarSettingsUi.set_status(_note, AISidebarI18n.get_text("mcp_settings_start_failed", {"port": res["port"], "error": res["error"]}), true)
	else:
		AISidebarSettingsUi.set_status(_note, AISidebarI18n.get_text("mcp_settings_port_saved"))

func _on_copy() -> void:
	var bridge := AISidebarMcpBridgeControl.instance
	if bridge == null or not bridge.is_running():
		return
	DisplayServer.clipboard_set(bridge.claude_add_command())
	AISidebarSettingsUi.set_status(_note, AISidebarI18n.get_text("mcp_settings_copied"))
