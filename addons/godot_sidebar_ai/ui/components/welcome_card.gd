@tool
extends PanelContainer
class_name AISidebarWelcomeCard

## Boş Sohbet Hoş Geldin ve Hızlı Başlangıç Kartı (Empty State & Suggestions) (SRP).
## Sohbet boşken kullanıcıya yapay zekanın hazır olduğunu gösterir ve
## tıklanabilir popüler başlangıç görevleri (öneri çipleri) sunar.

signal prompt_selected(prompt_text: String)

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

var _vbox: VBoxContainer

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _setup_ui() -> void:
	theme_type_variation = AISidebarThemeBuilder.CARD
	_build_content()

## Dil değişince metinleri seçili dilde yeniden kurar (dock `update_ui_language` çağırır).
func refresh_texts() -> void:
	_build_content()

func _build_content() -> void:
	if _vbox and is_instance_valid(_vbox):
		remove_child(_vbox)
		_vbox.free()
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	add_child(_vbox)
	
	# Başlık ve Rozet
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(header)
	
	var title_lbl = Label.new()
	title_lbl.text = AISidebarI18n.get_text("welcome_title")
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.theme_type_variation = AISidebarThemeBuilder.HEADER_TITLE
	header.add_child(title_lbl)
	
	var badge_lbl = Label.new()
	badge_lbl.text = AISidebarI18n.get_text("status_ready")
	badge_lbl.theme_type_variation = AISidebarThemeBuilder.STATUS_TEXT
	header.add_child(badge_lbl)
	
	# Açıklama
	var desc_lbl = Label.new()
	desc_lbl.text = AISidebarI18n.get_text("welcome_desc")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.theme_type_variation = AISidebarThemeBuilder.HINT_MUTED
	_vbox.add_child(desc_lbl)
	
	# Öneri Çipleri (Suggestion Chips)
	var suggestions: Array = []
	for i in range(1, 5):
		suggestions.append({
			"title": AISidebarI18n.get_text("welcome_suggestion_%d_title" % i),
			"prompt": AISidebarI18n.get_text("welcome_suggestion_%d_prompt" % i)
		})
	
	var chips_vbox = VBoxContainer.new()
	chips_vbox.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_XS))
	_vbox.add_child(chips_vbox)
	
	for s in suggestions:
		var btn = Button.new()
		btn.text = s["title"]
		AISidebarIconHelper.apply_tinted_icon(btn, "arrow-up-right", AISidebarTheme.COLOR_TEXT_MUTED, AISidebarTheme.ICON_SIZE_SM)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.focus_mode = Control.FOCUS_NONE
		btn.theme_type_variation = AISidebarThemeBuilder.CHIP_BUTTON
		var p_txt = s["prompt"]
		btn.pressed.connect(func(): prompt_selected.emit(p_txt))
		chips_vbox.add_child(btn)
