@tool
extends PanelContainer
class_name AISidebarWelcomeCard

## Boş Sohbet Hoş Geldin ve Hızlı Başlangıç Kartı (Empty State & Suggestions) (SRP).
## Sohbet boşken kullanıcıya yapay zekanın hazır olduğunu gösterir ve
## tıklanabilir popüler başlangıç görevleri (öneri çipleri) sunar.

signal prompt_selected(prompt_text: String)

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

var _vbox: VBoxContainer

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _setup_ui() -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(AISidebarTheme.RADIUS_LG)
	style.bg_color = Color(0.11, 0.13, 0.17, 0.90)
	style.border_color = Color(0.24, 0.28, 0.35, 0.45)
	style.set_border_width_all(1)
	style.content_margin_left = AISidebarTheme.SPACE_MD
	style.content_margin_top = AISidebarTheme.SPACE_MD
	style.content_margin_right = AISidebarTheme.SPACE_MD
	style.content_margin_bottom = AISidebarTheme.SPACE_MD
	add_theme_stylebox_override("panel", style)
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_SM)
	add_child(_vbox)
	
	# Başlık ve Rozet
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(header)
	
	var title_lbl = Label.new()
	title_lbl.text = "Godot AI Asistanı"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_HEADER)
	title_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
	header.add_child(title_lbl)
	
	var badge_lbl = Label.new()
	badge_lbl.text = "● Hazır"
	badge_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	badge_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_SUCCESS)
	header.add_child(badge_lbl)
	
	# Açıklama
	var desc_lbl = Label.new()
	desc_lbl.text = "Godot 4.7 ile tam entegre çalışır. Dosya/kod üretimi, sahne yönetimi, canlı hata ayıklama ve mimari netleştirme yapabilir.\n\nAşağıdaki hızlı başlangıç görevlerinden birini seçebilir veya alttaki kutuya doğrudan sorunuzu yazabilirsiniz:"
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
	desc_lbl.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
	_vbox.add_child(desc_lbl)
	
	# Öneri Çipleri (Suggestion Chips)
	var suggestions = [
		{"title": "Hexagon harita sistemi oluştur", "prompt": "Hexagon harita sistemi oluştur"},
		{"title": "Projeyi ve açık sahneyi analiz et", "prompt": "Projeyi ve aktif sahneyi incele"},
		{"title": "Karakter ve düşman sahnesi kur", "prompt": "Karakter ve düşman sahnesi kur"},
		{"title": "Canlı sahne ağacını incele", "prompt": "Oyundaki canlı sahne ağacını incele"}
	]
	
	var chips_vbox = VBoxContainer.new()
	chips_vbox.add_theme_constant_override("separation", AISidebarTheme.SPACE_XS)
	_vbox.add_child(chips_vbox)
	
	for s in suggestions:
		var btn = Button.new()
		btn.text = "💡 " + s["title"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
		btn.add_theme_color_override("font_hover_color", AISidebarTheme.COLOR_TEXT_PRIMARY)
		btn.add_theme_stylebox_override("normal", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_XS))
		btn.add_theme_stylebox_override("hover", AISidebarTheme.create_card_hover_style(AISidebarTheme.SPACE_XS))
		btn.add_theme_stylebox_override("pressed", AISidebarTheme.create_card_active_style(AISidebarTheme.SPACE_XS))
		var p_txt = s["prompt"]
		btn.pressed.connect(func(): prompt_selected.emit(p_txt))
		chips_vbox.add_child(btn)
