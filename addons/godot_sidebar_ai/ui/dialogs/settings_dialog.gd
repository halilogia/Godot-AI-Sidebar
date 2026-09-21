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

var tab_container: TabContainer = null
var provider_selector: OptionButton = null
var provider_hint_label: Label = null
var provider_lbl: Label = null
var temp_hint_lbl: Label = null
var reset_temp_btn: Button = null
var lang_selector: OptionButton = null
var lang_lbl: Label = null
var approve_mode_selector: OptionButton = null
var approve_mode_lbl: Label = null
var reset_prompt_btn: Button = null
var reset_prompt_hint: Label = null

var _tabs_built: bool = false

func _ready() -> void:
	title = AISidebarI18n.get_text("settings_title")
	ok_button_text = AISidebarI18n.get_text("btn_save_close")
	
	_ensure_provider_ui()
	_setup_temp_ui()
	_build_modern_tabs()
	
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
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_theme_constant_override("separation", 6)
		
		provider_lbl = Label.new()
		provider_lbl.text = AISidebarI18n.get_text("label_provider_type")
		provider_lbl.add_theme_font_size_override("font_size", 11)
		container.add_child(provider_lbl)
		
		provider_selector = OptionButton.new()
		provider_selector.add_item(AISidebarI18n.get_text("provider_antigravity"), 0)
		provider_selector.set_item_metadata(0, "antigravity_cli")
		provider_selector.add_item(AISidebarI18n.get_text("provider_openai"), 1)
		provider_selector.set_item_metadata(1, "openai_compatible")
		container.add_child(provider_selector)
		
		provider_hint_label = Label.new()
		provider_hint_label.theme_override_font_sizes.font_size = 10
		provider_hint_label.theme_override_colors.font_color = Color(0.4, 0.85, 0.4)
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
	if not temp_container:
		temp_container = find_child("TempContainer", true, false)
	if temp_container and not temp_container.has_node("TempActionRow"):
		var row = HBoxContainer.new()
		row.name = "TempActionRow"
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		temp_hint_lbl = Label.new()
		temp_hint_lbl.name = "TempHintLabel"
		temp_hint_lbl.text = AISidebarI18n.get_text("hint_temp_ideal")
		temp_hint_lbl.theme_override_font_sizes.font_size = 10
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

func _create_card(child_node: Control) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.16, 0.98)
	style.border_color = Color(0.22, 0.25, 0.33, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	
	if child_node:
		if child_node.get_parent():
			child_node.get_parent().remove_child(child_node)
		card.add_child(child_node)
		
	return card

func _build_modern_tabs() -> void:
	if _tabs_built:
		return
		
	var vbox = get_node_or_null("VBox")
	if not vbox:
		return
		
	_tabs_built = true
	
	tab_container = TabContainer.new()
	tab_container.name = "ModernTabContainer"
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Tab 1: Sağlayıcı (Provider)
	var tab_prov = VBoxContainer.new()
	tab_prov.name = "ProviderTab"
	tab_prov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_prov.add_theme_constant_override("separation", 10)
	
	var prov_node = vbox.get_node_or_null("ProviderContainer")
	if prov_node:
		tab_prov.add_child(_create_card(prov_node))
		
	var ep_box = VBoxContainer.new()
	ep_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ep_box.add_theme_constant_override("separation", 8)
	var url_node = vbox.get_node_or_null("UrlContainer")
	var key_node = vbox.get_node_or_null("KeyContainer")
	if url_node:
		if url_node.get_parent():
			url_node.get_parent().remove_child(url_node)
		ep_box.add_child(url_node)
	if key_node:
		if key_node.get_parent():
			key_node.get_parent().remove_child(key_node)
		ep_box.add_child(key_node)
	tab_prov.add_child(_create_card(ep_box))
	tab_container.add_child(tab_prov)
	
	# Tab 2: Model ve Parametreler (Params)
	var tab_params = VBoxContainer.new()
	tab_params.name = "ParamsTab"
	tab_params.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_params.add_theme_constant_override("separation", 10)
	
	var temp_node = vbox.get_node_or_null("TempContainer")
	if temp_node:
		tab_params.add_child(_create_card(temp_node))
		
	var max_node = vbox.get_node_or_null("MaxIterContainer")
	if max_node:
		tab_params.add_child(_create_card(max_node))
	tab_container.add_child(tab_params)
	
	# Tab 3: Görünüm ve Dil (Appearance)
	var tab_app = VBoxContainer.new()
	tab_app.name = "AppearanceTab"
	tab_app.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_app.add_theme_constant_override("separation", 10)
	
	var lang_box = VBoxContainer.new()
	lang_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_box.add_theme_constant_override("separation", 6)
	lang_lbl = Label.new()
	lang_lbl.text = AISidebarI18n.get_text("label_language")
	lang_lbl.add_theme_font_size_override("font_size", 11)
	lang_box.add_child(lang_lbl)
	
	lang_selector = OptionButton.new()
	lang_selector.add_item("Türkçe (TR)", 0)
	lang_selector.set_item_metadata(0, "tr")
	lang_selector.add_item("English (EN)", 1)
	lang_selector.set_item_metadata(1, "en")
	lang_box.add_child(lang_selector)
	tab_app.add_child(_create_card(lang_box))
	
	var app_box = VBoxContainer.new()
	app_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_box.add_theme_constant_override("separation", 6)
	approve_mode_lbl = Label.new()
	approve_mode_lbl.text = AISidebarI18n.get_text("label_auto_approve_mode")
	approve_mode_lbl.add_theme_font_size_override("font_size", 11)
	app_box.add_child(approve_mode_lbl)
	
	approve_mode_selector = OptionButton.new()
	approve_mode_selector.add_item(AISidebarI18n.get_text("mode_manual") + " (Tüm dosya işlemlerinde sor)", 0)
	approve_mode_selector.set_item_metadata(0, "MANUAL")
	approve_mode_selector.add_item(AISidebarI18n.get_text("mode_auto") + " (Güvenli okumalar otomatik)", 1)
	approve_mode_selector.set_item_metadata(1, "AUTO")
	approve_mode_selector.add_item(AISidebarI18n.get_text("mode_full_auto") + " (Tam otomatik)", 2)
	approve_mode_selector.set_item_metadata(2, "FULL_AUTO")
	app_box.add_child(approve_mode_selector)
	tab_app.add_child(_create_card(app_box))
	tab_container.add_child(tab_app)
	
	# Tab 4: Sistem Promptu (Prompt)
	var tab_prompt = VBoxContainer.new()
	tab_prompt.name = "PromptTab"
	tab_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_prompt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var prompt_node = vbox.get_node_or_null("PromptContainer")
	if prompt_node:
		var p_card = _create_card(prompt_node)
		p_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab_prompt.add_child(p_card)
		
		var p_actions = HBoxContainer.new()
		p_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reset_prompt_hint = Label.new()
		reset_prompt_hint.text = AISidebarI18n.get_text("hint_prompt_reset")
		reset_prompt_hint.theme_override_font_sizes.font_size = 10
		reset_prompt_hint.theme_override_colors.font_color = Color(0.55, 0.60, 0.70)
		reset_prompt_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_actions.add_child(reset_prompt_hint)
		
		reset_prompt_btn = Button.new()
		reset_prompt_btn.text = AISidebarI18n.get_text("btn_reset_prompt")
		reset_prompt_btn.pressed.connect(_on_reset_prompt_pressed)
		p_actions.add_child(reset_prompt_btn)
		prompt_node.add_child(p_actions)
		
	tab_container.add_child(tab_prompt)
	
	vbox.add_child(tab_container)

func _on_reset_prompt_pressed() -> void:
	if sys_prompt_edit:
		sys_prompt_edit.text = str(AISidebarConfig.DEFAULT_CONFIG.get("system_prompt", ""))

func update_labels() -> void:
	title = AISidebarI18n.get_text("settings_title")
	ok_button_text = AISidebarI18n.get_text("btn_save_close")
	
	if tab_container and tab_container.get_tab_count() >= 4:
		tab_container.set_tab_title(0, AISidebarI18n.get_text("tab_provider"))
		tab_container.set_tab_title(1, AISidebarI18n.get_text("tab_parameters"))
		tab_container.set_tab_title(2, AISidebarI18n.get_text("tab_appearance"))
		tab_container.set_tab_title(3, AISidebarI18n.get_text("tab_system_prompt"))
		
	if provider_lbl:
		provider_lbl.text = AISidebarI18n.get_text("label_provider_type")
	if provider_selector:
		provider_selector.set_item_text(0, AISidebarI18n.get_text("provider_antigravity"))
		provider_selector.set_item_text(1, AISidebarI18n.get_text("provider_openai"))
	if temp_hint_lbl:
		temp_hint_lbl.text = AISidebarI18n.get_text("hint_temp_ideal")
	if reset_temp_btn:
		reset_temp_btn.text = AISidebarI18n.get_text("btn_reset_temp")
	if lang_lbl:
		lang_lbl.text = AISidebarI18n.get_text("label_language")
	if approve_mode_lbl:
		approve_mode_lbl.text = AISidebarI18n.get_text("label_auto_approve_mode")
	if reset_prompt_btn:
		reset_prompt_btn.text = AISidebarI18n.get_text("btn_reset_prompt")
	if reset_prompt_hint:
		reset_prompt_hint.text = AISidebarI18n.get_text("hint_prompt_reset")
		
	var url_lbl = find_child("Label", true, false)
	var url_cont = find_child("UrlContainer", true, false)
	if url_cont:
		var u_l = url_cont.get_node_or_null("Label")
		if u_l:
			u_l.text = AISidebarI18n.get_text("label_base_url")
			
	var key_cont = find_child("KeyContainer", true, false)
	if key_cont:
		var k_l = key_cont.get_node_or_null("Label")
		if k_l:
			k_l.text = AISidebarI18n.get_text("label_api_key")
			
	var temp_cont = find_child("TempContainer", true, false)
	if temp_cont:
		var t_l = temp_cont.get_node_or_null("Label")
		if t_l:
			t_l.text = AISidebarI18n.get_text("label_temperature")
			
	var max_cont = find_child("MaxIterContainer", true, false)
	if max_cont:
		var m_l = max_cont.get_node_or_null("Label")
		if m_l:
			m_l.text = AISidebarI18n.get_text("label_max_iterations")
			
	var prompt_cont = find_child("PromptContainer", true, false)
	if prompt_cont:
		var p_l = prompt_cont.get_node_or_null("Label")
		if p_l:
			p_l.text = AISidebarI18n.get_text("label_system_prompt")
			
	if base_url_line:
		base_url_line.placeholder_text = AISidebarI18n.get_text("placeholder_base_url")

func open_settings() -> void:
	_ensure_provider_ui()
	_setup_temp_ui()
	_build_modern_tabs()
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
		
	if lang_selector:
		var cur_lang = config.get("language", "tr")
		lang_selector.selected = 1 if cur_lang == "en" else 0
		
	if approve_mode_selector:
		var cur_mode = config.get("auto_approve_mode", "MANUAL")
		if cur_mode == "FULL_AUTO":
			approve_mode_selector.selected = 2
		elif cur_mode == "AUTO":
			approve_mode_selector.selected = 1
		else:
			approve_mode_selector.selected = 0
		
	popup_centered(Vector2i(620, 560))

func _on_provider_selected(idx: int) -> void:
	_apply_provider_ui_state(idx)

func _apply_provider_ui_state(idx: int) -> void:
	var is_antigravity = (idx == 0)
	var url_container = find_child("UrlContainer", true, false)
	var key_container = find_child("KeyContainer", true, false)
	
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
	if lang_selector:
		var new_lang = str(lang_selector.get_item_metadata(lang_selector.selected))
		config["language"] = new_lang
		AISidebarI18n.set_language(new_lang)
	if approve_mode_selector:
		var new_mode = str(approve_mode_selector.get_item_metadata(approve_mode_selector.selected))
		config["auto_approve_mode"] = new_mode
		
	AISidebarConfig.save_config(config)
	settings_saved.emit()
