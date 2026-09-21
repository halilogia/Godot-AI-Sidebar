@tool
extends AcceptDialog

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

signal settings_saved()

@onready var base_url_line: LineEdit = $VBox/UrlContainer/BaseUrlEdit
@onready var api_key_line: LineEdit = $VBox/KeyContainer/ApiKeyEdit
@onready var temp_slider: HSlider = $VBox/TempContainer/TempSlider
@onready var temp_val_label: Label = $VBox/TempContainer/TempValLabel
@onready var max_iter_spin: SpinBox = $VBox/MaxIterContainer/MaxIterSpin
@onready var sys_prompt_edit: TextEdit = $VBox/PromptContainer/SysPromptEdit

var provider_selector: OptionButton = null
var provider_hint_label: Label = null
var provider_lbl: Label = null
var temp_hint_lbl: Label = null
var reset_temp_btn: Button = null

func _ready() -> void:
	title = AISidebarI18n.get_text("settings_title")
	ok_button_text = AISidebarI18n.get_text("btn_save_close")
	
	_ensure_provider_ui()
	_setup_temp_ui()
	
	if not confirmed.is_connected(_on_confirmed):
		confirmed.connect(_on_confirmed)
	if temp_slider and not temp_slider.value_changed.is_connected(_on_temp_changed):
		temp_slider.value_changed.connect(_on_temp_changed)
		
	update_labels()

func _ensure_provider_ui() -> void:
	var vbox = get_node_or_null("VBox")
	if not vbox:
		return

	var existing = vbox.get_node_or_null("ProviderContainer")
	if not existing:
		var container = VBoxContainer.new()
		container.name = "ProviderContainer"
		
		provider_lbl = Label.new()
		provider_lbl.text = AISidebarI18n.get_text("label_provider_type")
		container.add_child(provider_lbl)
		
		provider_selector = OptionButton.new()
		provider_selector.add_item(AISidebarI18n.get_text("provider_antigravity"), 0)
		provider_selector.set_item_metadata(0, "antigravity_cli")
		provider_selector.add_item(AISidebarI18n.get_text("provider_openai"), 1)
		provider_selector.set_item_metadata(1, "openai_compatible")
		container.add_child(provider_selector)
		
		provider_hint_label = Label.new()
		provider_hint_label.theme_override_font_sizes.font_size = 11
		provider_hint_label.theme_override_colors.font_color = Color(0.4, 0.8, 0.4)
		provider_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(provider_hint_label)
		
		vbox.add_child(container)
		vbox.move_child(container, 0)
		
		provider_selector.item_selected.connect(_on_provider_selected)
	else:
		provider_lbl = existing.get_node_or_null("Label")
		provider_selector = existing.get_node_or_null("OptionButton")
		provider_hint_label = existing.get_node_or_null("HintLabel")

func _setup_temp_ui() -> void:
	if not temp_slider:
		return
	temp_slider.scrollable = false
	if not temp_slider.gui_input.is_connected(_on_temp_slider_gui_input):
		temp_slider.gui_input.connect(_on_temp_slider_gui_input)
		
	var temp_container = get_node_or_null("VBox/TempContainer")
	if temp_container and not temp_container.has_node("TempActionRow"):
		var row = HBoxContainer.new()
		row.name = "TempActionRow"
		
		temp_hint_lbl = Label.new()
		temp_hint_lbl.name = "TempHintLabel"
		temp_hint_lbl.text = AISidebarI18n.get_text("hint_temp_ideal")
		temp_hint_lbl.theme_override_font_sizes.font_size = 11
		temp_hint_lbl.theme_override_colors.font_color = Color(0.5, 0.7, 0.9)
		temp_hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		temp_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(temp_hint_lbl)
		
		reset_temp_btn = Button.new()
		reset_temp_btn.name = "ResetTempBtn"
		reset_temp_btn.text = AISidebarI18n.get_text("btn_reset_temp")
		reset_temp_btn.tooltip_text = "0.20 (İdeal)"
		reset_temp_btn.pressed.connect(_on_reset_temp_pressed)
		row.add_child(reset_temp_btn)
		
		temp_container.add_child(row)
	elif temp_container:
		var existing_row = temp_container.get_node_or_null("TempActionRow")
		if existing_row:
			temp_hint_lbl = existing_row.get_node_or_null("TempHintLabel")
			reset_temp_btn = existing_row.get_node_or_null("ResetTempBtn")

func _on_temp_slider_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			temp_slider.accept_event()

func _on_reset_temp_pressed() -> void:
	if temp_slider:
		temp_slider.value = 0.2
		_on_temp_changed(0.2)

func update_labels() -> void:
	title = AISidebarI18n.get_text("settings_title")
	ok_button_text = AISidebarI18n.get_text("btn_save_close")
	
	if provider_lbl:
		provider_lbl.text = AISidebarI18n.get_text("label_provider_type")
	if provider_selector:
		provider_selector.set_item_text(0, AISidebarI18n.get_text("provider_antigravity"))
		provider_selector.set_item_text(1, AISidebarI18n.get_text("provider_openai"))
	if temp_hint_lbl:
		temp_hint_lbl.text = AISidebarI18n.get_text("hint_temp_ideal")
	if reset_temp_btn:
		reset_temp_btn.text = AISidebarI18n.get_text("btn_reset_temp")
		
	var url_lbl = get_node_or_null("VBox/UrlContainer/Label")
	if url_lbl:
		url_lbl.text = AISidebarI18n.get_text("label_base_url")
		
	var key_lbl = get_node_or_null("VBox/KeyContainer/Label")
	if key_lbl:
		key_lbl.text = AISidebarI18n.get_text("label_api_key")
		
	var temp_lbl = get_node_or_null("VBox/TempContainer/Label")
	if temp_lbl:
		temp_lbl.text = AISidebarI18n.get_text("label_temperature")
		
	var max_lbl = get_node_or_null("VBox/MaxIterContainer/Label")
	if max_lbl:
		max_lbl.text = AISidebarI18n.get_text("label_max_iterations")
		
	var prompt_lbl = get_node_or_null("VBox/PromptContainer/Label")
	if prompt_lbl:
		prompt_lbl.text = AISidebarI18n.get_text("label_system_prompt")
		
	if base_url_line:
		base_url_line.placeholder_text = AISidebarI18n.get_text("placeholder_base_url")

func open_settings() -> void:
	_ensure_provider_ui()
	_setup_temp_ui()
	update_labels()
	var config = AISidebarConfig.load_config()
	var current_prov = config.get("provider_type", "antigravity_cli")
	
	if provider_selector:
		if current_prov == "openai_compatible":
			provider_selector.selected = 1
		else:
			provider_selector.selected = 0
		_apply_provider_ui_state(provider_selector.selected)
		
	if base_url_line:
		base_url_line.text = config.get("base_url", "http://localhost:20128/v1")
	if api_key_line:
		api_key_line.text = config.get("api_key", "")
	if temp_slider:
		temp_slider.value = config.get("temperature", 0.2)
		_on_temp_changed(temp_slider.value)
	if max_iter_spin:
		max_iter_spin.value = config.get("max_agent_steps", config.get("max_iterations", 20))
	if sys_prompt_edit:
		sys_prompt_edit.text = config.get("system_prompt", "")
		
	popup_centered(Vector2i(560, 550))

func _on_provider_selected(idx: int) -> void:
	_apply_provider_ui_state(idx)

func _apply_provider_ui_state(idx: int) -> void:
	var is_antigravity = (idx == 0)
	var url_container = get_node_or_null("VBox/UrlContainer")
	var key_container = get_node_or_null("VBox/KeyContainer")
	
	if is_antigravity:
		if url_container:
			url_container.modulate = Color(1, 1, 1, 0.4)
		if key_container:
			key_container.modulate = Color(1, 1, 1, 0.4)
		if base_url_line:
			base_url_line.editable = false
		if api_key_line:
			api_key_line.editable = false
		if provider_hint_label:
			provider_hint_label.text = "✓ Google Antigravity CLI doğrudan yerel oturumu kullanır. 3. taraf proxy/MITM içermez; API Key veya Base URL gerekmez."
			provider_hint_label.theme_override_colors.font_color = Color(0.4, 0.85, 0.4)
	else:
		if url_container:
			url_container.modulate = Color(1, 1, 1, 1.0)
		if key_container:
			key_container.modulate = Color(1, 1, 1, 1.0)
		if base_url_line:
			base_url_line.editable = true
		if api_key_line:
			api_key_line.editable = true
		if provider_hint_label:
			provider_hint_label.text = "ℹ️ OpenAI uyumlu yerel veya bulut API endpointi (9Router, Ollama, OpenRouter vb.)."
			provider_hint_label.theme_override_colors.font_color = Color(0.8, 0.8, 0.4)

func _on_temp_changed(val: float) -> void:
	if temp_val_label:
		var snapped_val = snappedf(val, 0.05)
		if is_equal_approx(snapped_val, 0.2):
			temp_val_label.text = "0.20 (İdeal / Kararlı)"
			temp_val_label.theme_override_colors.font_color = Color(0.4, 0.9, 0.5)
		elif snapped_val > 0.6:
			temp_val_label.text = "%0.2f (Yüksek Halüsinasyon Riski)" % snapped_val
			temp_val_label.theme_override_colors.font_color = Color(0.9, 0.4, 0.4)
		else:
			temp_val_label.text = "%0.2f" % snapped_val
			temp_val_label.theme_override_colors.font_color = Color(0.7, 0.7, 0.7)

func _on_confirmed() -> void:
	var config = AISidebarConfig.load_config()
	if provider_selector:
		var prov_meta = provider_selector.get_item_metadata(provider_selector.selected)
		config["provider_type"] = str(prov_meta)
	if base_url_line:
		config["base_url"] = base_url_line.text.strip_edges()
	if api_key_line:
		config["api_key"] = api_key_line.text.strip_edges()
	if temp_slider:
		config["temperature"] = snappedf(temp_slider.value, 0.05)
	if max_iter_spin:
		var steps_val = int(max_iter_spin.value)
		config["max_agent_steps"] = steps_val
		config["max_iterations"] = steps_val
	if sys_prompt_edit:
		config["system_prompt"] = sys_prompt_edit.text
		
	AISidebarConfig.save_config(config)
	settings_saved.emit()
