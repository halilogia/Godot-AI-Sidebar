@tool
extends VBoxContainer
class_name AISidebarMcpSettingsView

## Ayarlar → Dış Ajan (MCP): köprünün durumu, aç / kapa, Claude Code bağlantı komutunu panoya
## kopyalama. /mcp komutuyla aynı kontrol yüzeyini (AISidebarMcpBridgeControl) kullanır. Token
## arayüzde yalnız ilk 4 karakteriyle görünür; tamamı yalnız panoya gider.

const AISidebarMcpBridgeControl = preload("res://addons/godot_sidebar_ai/core/bridge/mcp_bridge_control.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

var _status: Label
var _toggle_btn: Button
var _copy_btn: Button
var _command: Label
var _note: Label

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var hint := Label.new()
	hint.text = AISidebarI18n.get_text("mcp_settings_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	add_child(hint)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var row := HBoxContainer.new()
	add_child(row)
	_toggle_btn = Button.new()
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.pressed.connect(_on_toggle)
	row.add_child(_toggle_btn)
	_copy_btn = Button.new()
	_copy_btn.focus_mode = Control.FOCUS_NONE
	_copy_btn.text = AISidebarI18n.get_text("mcp_settings_copy")
	_copy_btn.pressed.connect(_on_copy)
	row.add_child(_copy_btn)
	_command = Label.new()
	_command.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_command.add_theme_font_size_override("font_size", 11)
	add_child(_command)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 11)
	add_child(_note)
	refresh()

func refresh() -> void:
	if _status == null:
		return
	var bridge := AISidebarMcpBridgeControl.instance
	_note.text = ""
	if bridge == null:
		_status.text = AISidebarI18n.get_text("mcp_settings_unavailable")
		_toggle_btn.visible = false
		_copy_btn.visible = false
		_command.text = ""
		return
	_toggle_btn.visible = true
	var running := bridge.is_running()
	if running:
		_status.text = AISidebarI18n.get_text("mcp_settings_on", {"endpoint": bridge.endpoint(), "count": bridge.tool_count()})
		_toggle_btn.text = AISidebarI18n.get_text("mcp_settings_turn_off")
		_command.text = bridge.masked_claude_add_command()
	else:
		_status.text = AISidebarI18n.get_text("mcp_settings_off")
		_toggle_btn.text = AISidebarI18n.get_text("mcp_settings_turn_on")
		_command.text = ""
	_copy_btn.visible = running

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
		_note.text = AISidebarI18n.get_text("mcp_settings_start_failed", {"port": res["port"], "error": res["error"]})

func _on_copy() -> void:
	var bridge := AISidebarMcpBridgeControl.instance
	if bridge == null or not bridge.is_running():
		return
	DisplayServer.clipboard_set(bridge.claude_add_command())
	_note.text = AISidebarI18n.get_text("mcp_settings_copied")
