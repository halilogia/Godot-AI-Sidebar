@tool
extends PanelContainer
class_name AISidebarClarificationCard

## Kullanıcıdan Netleştirme / Soru İsteme Kartı (Clarification Card) (SRP).
## Belirsiz durumlarda hızlı butonlar ve serbest metin kutusu ile soru sorar.

signal response_submitted(answer: String)

const AISidebarStatusIcon = preload("res://addons/godot_sidebar_ai/ui/components/status_icon.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

var question_text: String = ""
var quick_options: Array = []
var is_answered: bool = false

var _question_lbl: RichTextLabel
var _options_container: VBoxContainer
var _input_line: LineEdit
var _send_btn: Button
var _status_lbl: Label
var _status_icon: AISidebarStatusIcon
var _input_row: HBoxContainer
## History replay'de gösterilecek geçmiş cevap (boşsa kart canlıdır).
var _replayed_answer: String = ""

func _init(p_question: String = "", p_options: Array = []) -> void:
	question_text = p_question
	quick_options = p_options

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(0.13, 0.16, 0.22, 0.95)
	style.border_color = Color(0.85, 0.65, 0.2, 0.85) # Amber/Gold accent for question
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	# 1. Başlık & Soru
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	var header_icon = AISidebarStatusIcon.new(16)
	header_icon.set_icon("message-circle-question-mark", Color(0.95, 0.75, 0.3))
	header_hbox.add_child(header_icon)
	
	var title_lbl = Label.new()
	title_lbl.text = AISidebarI18n.get_text("clarification_title")
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
	header_hbox.add_child(title_lbl)
	vbox.add_child(header_hbox)
	
	_question_lbl = RichTextLabel.new()
	_question_lbl.text = question_text
	_question_lbl.fit_content = true
	_question_lbl.scroll_active = false
	_question_lbl.selection_enabled = true
	_question_lbl.context_menu_enabled = true
	_question_lbl.focus_mode = Control.FOCUS_CLICK
	_question_lbl.add_theme_font_size_override("normal_font_size", 12)
	_question_lbl.add_theme_color_override("default_color", Color(0.9, 0.9, 0.95))
	vbox.add_child(_question_lbl)
	
	# 2. Hızlı Seçenek Butonları (Quick Choices)
	if quick_options.size() > 0:
		# Dikey liste: her seçenek tam genişlikte ve satır kaydırır. (Yatay akışta satır
		# kaydıran butonlar en dar hallerine sıkışıyordu; kaydırmayanlar ise dar dock'u taşırıyordu.)
		_options_container = VBoxContainer.new()
		_options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_options_container.add_theme_constant_override("separation", 6)
		
		for opt in quick_options:
			var opt_str = str(opt)
			var btn = Button.new()
			btn.text = opt_str
			# Uzun seçenek dar dock'u genişletmesin: satır kaydırır (metin kaybolmaz).
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", 11)
			
			var btn_style = StyleBoxFlat.new()
			btn_style.set_corner_radius_all(4)
			btn_style.bg_color = Color(0.2, 0.25, 0.35, 0.9)
			btn_style.border_color = Color(0.4, 0.55, 0.75, 0.8)
			btn_style.set_border_width_all(1)
			btn_style.content_margin_left = 10
			btn_style.content_margin_top = 4
			btn_style.content_margin_right = 10
			btn_style.content_margin_bottom = 4
			btn.add_theme_stylebox_override("normal", btn_style)
			
			btn.pressed.connect(func(): _on_option_selected(opt_str))
			_options_container.add_child(btn)
			
		vbox.add_child(_options_container)
		
	# 3. Serbest Metin Girişi (Free Text Response)
	var input_hbox = HBoxContainer.new()
	input_hbox.add_theme_constant_override("separation", 4)
	
	_input_line = LineEdit.new()
	_input_line.placeholder_text = AISidebarI18n.get_text("clarification_placeholder")
	_input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_line.add_theme_font_size_override("font_size", 11)
	_input_line.text_submitted.connect(_on_text_submitted)
	input_hbox.add_child(_input_line)
	
	_send_btn = Button.new()
	_send_btn.text = AISidebarI18n.get_text("btn_send")
	_send_btn.add_theme_font_size_override("font_size", 11)
	_send_btn.pressed.connect(func(): _on_text_submitted(_input_line.text))
	input_hbox.add_child(_send_btn)
	
	vbox.add_child(input_hbox)
	_input_row = input_hbox
	
	# 4. Yanıtlandı Durum Etiketi
	var status_row = HBoxContainer.new()
	status_row.visible = false
	status_row.add_theme_constant_override("separation", 4)
	vbox.add_child(status_row)
	_status_icon = AISidebarStatusIcon.new()
	_status_icon.set_icon("check", Color(0.4, 0.85, 0.5))
	status_row.add_child(_status_icon)
	_status_lbl = Label.new()
	_status_lbl.visible = false
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
	status_row.add_child(_status_lbl)
	
	add_child(vbox)
	if not _replayed_answer.is_empty():
		_apply_answered_view()

## History replay: geçmişte yanıtlanmış soruyu salt-okunur gösterir (sinyal yok).
## Kart ağaca eklenmeden önce çağrılabilir; görünüm _ready'de kurulur.
func show_as_answered(answer: String) -> void:
	is_answered = true
	_replayed_answer = answer
	if _status_lbl:
		_apply_answered_view()

func _apply_answered_view() -> void:
	if _options_container:
		_options_container.visible = false
	if _input_row:
		_input_row.visible = false
	_show_status(AISidebarI18n.get_text("clarification_answered", {"answer": _replayed_answer}))

func _show_status(txt: String) -> void:
	_status_lbl.text = txt
	_status_lbl.visible = true
	_status_lbl.get_parent().visible = true

func _on_option_selected(option_value: String) -> void:
	if is_answered:
		return
	_submit_answer(option_value)

func _on_text_submitted(text_value: String) -> void:
	var trimmed = text_value.strip_edges()
	if is_answered or trimmed.is_empty():
		return
	_submit_answer(trimmed)

func _submit_answer(answer: String) -> void:
	is_answered = true
	
	# Kontrolleri devre dışı bırak
	if _options_container:
		for child in _options_container.get_children():
			if child is Button:
				child.disabled = true
	if _input_line:
		_input_line.editable = false
	if _send_btn:
		_send_btn.disabled = true
		
	if _status_lbl:
		_show_status(AISidebarI18n.get_text("clarification_answered", {"answer": answer}))
		
	response_submitted.emit(answer)
