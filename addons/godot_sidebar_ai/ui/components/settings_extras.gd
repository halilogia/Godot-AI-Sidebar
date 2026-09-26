@tool
extends RefCounted
class_name AISidebarSettingsExtras

## Ayarlar penceresinin sahnede olmayan denetimleri (settings_dialog.gd'yi şişirmemek için ayrı birim):
##   Sağlayıcı sayfası → Gelişmiş: yanıtları akışla al (stream), görüntü desteği (vision_capable: otomatik / var / yok)
##   Görünüm & Dil sayfası → Onaylar: silmeden önce sor, var olan dosyanın üzerine yazmadan önce sor
## Pencere açılırken config'ten yüklenir, "Kaydet ve Kapat"ta config sözlüğüne yazılır.

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

var stream_check: CheckBox
var vision_opt: OptionButton
var delete_check: CheckBox
var overwrite_check: CheckBox
var _labels: Dictionary = {}  # Label -> i18n anahtarı

func build(provider_page: Control, approval_page: Control) -> void:
	if stream_check != null:
		return
	var adv := _card(provider_page, "settings_advanced_title")
	stream_check = CheckBox.new()
	adv.add_child(stream_check)
	_hint(adv, "settings_stream_hint")
	var vision_row := HBoxContainer.new()
	adv.add_child(vision_row)
	var vision_lbl := Label.new()
	_labels[vision_lbl] = "settings_vision"
	vision_row.add_child(vision_lbl)
	vision_opt = OptionButton.new()
	vision_opt.add_item("", 0)
	vision_opt.add_item("", 1)
	vision_opt.add_item("", 2)
	vision_row.add_child(vision_opt)
	_hint(adv, "settings_vision_hint")

	var appr := _card(approval_page, "settings_approvals_title")
	delete_check = CheckBox.new()
	appr.add_child(delete_check)
	overwrite_check = CheckBox.new()
	appr.add_child(overwrite_check)
	_hint(appr, "settings_approvals_hint")
	update_labels()

func _card(page: Control, title_key: String) -> VBoxContainer:
	var card := PanelContainer.new()
	page.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var title := Label.new()
	_labels[title] = title_key
	box.add_child(title)
	return box

func _hint(parent: Control, key: String) -> void:
	var h := Label.new()
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_theme_font_size_override("font_size", 11)
	h.modulate = Color(1, 1, 1, 0.7)
	_labels[h] = key
	parent.add_child(h)

func update_labels() -> void:
	if stream_check == null:
		return
	for l: Variant in _labels.keys():
		var lbl: Label = l
		lbl.text = AISidebarI18n.get_text(str(_labels[l]))
	stream_check.text = AISidebarI18n.get_text("settings_stream")
	vision_opt.set_item_text(0, AISidebarI18n.get_text("settings_vision_auto"))
	vision_opt.set_item_text(1, AISidebarI18n.get_text("settings_vision_on"))
	vision_opt.set_item_text(2, AISidebarI18n.get_text("settings_vision_off"))
	delete_check.text = AISidebarI18n.get_text("settings_require_delete")
	overwrite_check.text = AISidebarI18n.get_text("settings_require_overwrite")

func load_from(cfg: Dictionary) -> void:
	if stream_check == null:
		return
	stream_check.button_pressed = cfg.get("stream", true) == true
	var vision: Variant = cfg.get("vision_capable", null)
	vision_opt.selected = 0 if not (vision is bool) else (1 if vision == true else 2)
	delete_check.button_pressed = cfg.get("require_delete_approval", true) == true
	overwrite_check.button_pressed = cfg.get("require_overwrite_approval", true) == true

func write_to(cfg: Dictionary) -> void:
	if stream_check == null:
		return
	cfg["stream"] = stream_check.button_pressed
	cfg["vision_capable"] = null if vision_opt.selected == 0 else (vision_opt.selected == 1)
	cfg["require_delete_approval"] = delete_check.button_pressed
	cfg["require_overwrite_approval"] = overwrite_check.button_pressed
