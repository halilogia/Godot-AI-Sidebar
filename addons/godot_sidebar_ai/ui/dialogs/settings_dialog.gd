@tool
extends AcceptDialog

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

signal settings_saved()

@onready var base_url_line: LineEdit = find_child("BaseUrlEdit", true, false)
@onready var api_key_line: LineEdit = find_child("ApiKeyEdit", true, false)
@onready var temp_slider: HSlider = find_child("TempSlider", true, false)
@onready var temp_val_label: Label = find_child("TempValLabel", true, false)
@onready var max_iter_spin: SpinBox = find_child("MaxIterSpin", true, false)
@onready var sys_prompt_edit: TextEdit = find_child("SysPromptEdit", true, false)

@onready var provider_selector: OptionButton = find_child("ProviderSelector", true, false)
@onready var provider_hint_label: Label = find_child("HintLabel", true, false)

@onready var lang_selector: OptionButton = find_child("LangSelector", true, false)
@onready var approve_mode_selector: OptionButton = find_child("ApproveModeSelector", true, false)

@onready var reset_temp_btn: Button = find_child("ResetTempBtn", true, false)
@onready var reset_prompt_btn: Button = find_child("ResetPromptBtn", true, false)

@onready var btn_nav_provider: Button = find_child("BtnNavProvider", true, false)
@onready var btn_nav_params: Button = find_child("BtnNavParams", true, false)
@onready var btn_nav_appearance: Button = find_child("BtnNavAppearance", true, false)
@onready var btn_nav_prompt: Button = find_child("BtnNavPrompt", true, false)

@onready var page_provider: Control = find_child("PageProvider", true, false)
@onready var page_params: Control = find_child("PageParams", true, false)
@onready var page_appearance: Control = find_child("PageAppearance", true, false)
@onready var page_prompt: Control = find_child("PagePrompt", true, false)

var _active_category: int = 0

func _ensure_nodes() -> void:
	if not base_url_line: base_url_line = find_child("BaseUrlEdit", true, false)
	if not api_key_line: api_key_line = find_child("ApiKeyEdit", true, false)
	if not temp_slider: temp_slider = find_child("TempSlider", true, false)
	if not temp_val_label: temp_val_label = find_child("TempValLabel", true, false)
	if not max_iter_spin: max_iter_spin = find_child("MaxIterSpin", true, false)
	if not sys_prompt_edit: sys_prompt_edit = find_child("SysPromptEdit", true, false)
	if not provider_selector: provider_selector = find_child("ProviderSelector", true, false)
	if not provider_hint_label: provider_hint_label = find_child("HintLabel", true, false)
	if not lang_selector: lang_selector = find_child("LangSelector", true, false)
	if not approve_mode_selector: approve_mode_selector = find_child("ApproveModeSelector", true, false)
	if not reset_temp_btn: reset_temp_btn = find_child("ResetTempBtn", true, false)
	if not reset_prompt_btn: reset_prompt_btn = find_child("ResetPromptBtn", true, false)
	if not btn_nav_provider: btn_nav_provider = find_child("BtnNavProvider", true, false)
	if not btn_nav_params: btn_nav_params = find_child("BtnNavParams", true, false)
	if not btn_nav_appearance: btn_nav_appearance = find_child("BtnNavAppearance", true, false)
	if not btn_nav_prompt: btn_nav_prompt = find_child("BtnNavPrompt", true, false)
	if not page_provider: page_provider = find_child("PageProvider", true, false)
	if not page_params: page_params = find_child("PageParams", true, false)
	if not page_appearance: page_appearance = find_child("PageAppearance", true, false)
	if not page_prompt: page_prompt = find_child("PagePrompt", true, false)

func _ready() -> void:
	title = AISidebarI18n.get_text("settings_title")
	ok_button_text = AISidebarI18n.get_text("btn_save_close")
	
	_ensure_nodes()
	_setup_nav()
	_setup_options()
	_setup_temp()
	_apply_styles()
	
	if not confirmed.is_connected(_on_confirmed):
		confirmed.connect(_on_confirmed)
		
	update_labels()
	_select_category(0)

func _setup_nav() -> void:
	if btn_nav_provider and not btn_nav_provider.pressed.is_connected(func(): _select_category(0)):
		btn_nav_provider.pressed.connect(func(): _select_category(0))
	if btn_nav_params and not btn_nav_params.pressed.is_connected(func(): _select_category(1)):
		btn_nav_params.pressed.connect(func(): _select_category(1))
	if btn_nav_appearance and not btn_nav_appearance.pressed.is_connected(func(): _select_category(2)):
		btn_nav_appearance.pressed.connect(func(): _select_category(2))
	if btn_nav_prompt and not btn_nav_prompt.pressed.is_connected(func(): _select_category(3)):
		btn_nav_prompt.pressed.connect(func(): _select_category(3))

func _select_category(idx: int) -> void:
	_active_category = idx
	if page_provider: page_provider.visible = (idx == 0)
	if page_params: page_params.visible = (idx == 1)
	if page_appearance: page_appearance.visible = (idx == 2)
	if page_prompt: page_prompt.visible = (idx == 3)
	
	_update_nav_buttons()

func _update_nav_buttons() -> void:
	var btns = [btn_nav_provider, btn_nav_params, btn_nav_appearance, btn_nav_prompt]
	for i in range(btns.size()):
		var b = btns[i]
		if b:
			var is_active = (i == _active_category)
			var st = StyleBoxFlat.new()
			st.bg_color = AISidebarTheme.COLOR_BG_ACTIVE if is_active else Color(0.10, 0.11, 0.15, 0.6)
			st.border_color = AISidebarTheme.COLOR_BORDER_FOCUS if is_active else Color.TRANSPARENT
			st.set_border_width_all(1)
			st.set_corner_radius_all(AISidebarTheme.RADIUS_SM)
			st.content_margin_left = AISidebarTheme.SPACE_SM
			st.content_margin_right = AISidebarTheme.SPACE_SM
			st.content_margin_top = AISidebarTheme.SPACE_XS
			st.content_margin_bottom = AISidebarTheme.SPACE_XS
			b.add_theme_stylebox_override("normal", st)
			b.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY if is_active else AISidebarTheme.COLOR_TEXT_SECONDARY)

func _setup_options() -> void:
	if provider_selector and provider_selector.item_count == 0:
		provider_selector.add_item(AISidebarI18n.get_text("provider_antigravity"), 0)
		provider_selector.set_item_metadata(0, "antigravity_cli")
		provider_selector.add_item(AISidebarI18n.get_text("provider_openai"), 1)
		provider_selector.set_item_metadata(1, "openai_compatible")
		provider_selector.item_selected.connect(_on_provider_selected)
		
	if lang_selector and lang_selector.item_count == 0:
		lang_selector.add_item("Türkçe (TR)", 0)
		lang_selector.set_item_metadata(0, "tr")
		lang_selector.add_item("English (EN)", 1)
		lang_selector.set_item_metadata(1, "en")
		
	if approve_mode_selector and approve_mode_selector.item_count == 0:
		approve_mode_selector.add_item("Manual (Her dosya işleminde onay sor)", 0)
		approve_mode_selector.set_item_metadata(0, "MANUAL")
		approve_mode_selector.add_item("Auto (Güvenli okumalar otomatik, yazma onaylı)", 1)
		approve_mode_selector.set_item_metadata(1, "AUTO")
		approve_mode_selector.add_item("Full Auto (Tam otomatik)", 2)
		approve_mode_selector.set_item_metadata(2, "FULL_AUTO")
		
	if reset_prompt_btn and not reset_prompt_btn.pressed.is_connected(_on_reset_prompt_pressed):
		reset_prompt_btn.pressed.connect(_on_reset_prompt_pressed)

func _setup_temp() -> void:
	if temp_slider:
		temp_slider.scrollable = false
		if not temp_slider.gui_input.is_connected(_on_temp_slider_gui_input):
			temp_slider.gui_input.connect(_on_temp_slider_gui_input)
		if not temp_slider.value_changed.is_connected(_on_temp_changed):
			temp_slider.value_changed.connect(_on_temp_changed)
			
	if reset_temp_btn and not reset_temp_btn.pressed.is_connected(_on_reset_temp_pressed):
		reset_temp_btn.pressed.connect(_on_reset_temp_pressed)

func _on_temp_slider_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if temp_slider:
				temp_slider.accept_event()

func _on_reset_temp_pressed() -> void:
	if temp_slider:
		temp_slider.value = 0.20
		_on_temp_changed(0.20)

func _on_reset_prompt_pressed() -> void:
	if sys_prompt_edit:
		sys_prompt_edit.text = str(AISidebarConfig.DEFAULT_CONFIG.get("system_prompt", ""))

func _apply_styles() -> void:
	# Card panelleri
	var card_names = [
		"NavPanel", "ProviderCard", "EndpointCard", "TempCard",
		"MaxIterCard", "LangCard", "ApprovalCard", "PromptCard"
	]
	for cn in card_names:
		var p = find_child(cn, true, false)
		if p and p is PanelContainer:
			p.add_theme_stylebox_override("panel", AISidebarTheme.create_card_style(false, AISidebarTheme.SPACE_MD))
			
	# Input alanları
	if base_url_line:
		base_url_line.add_theme_stylebox_override("normal", AISidebarTheme.create_input_style())
	if api_key_line:
		api_key_line.add_theme_stylebox_override("normal", AISidebarTheme.create_input_style())

func update_labels() -> void:
	title = AISidebarI18n.get_text("settings_title")
	ok_button_text = AISidebarI18n.get_text("btn_save_close")
	
	if btn_nav_provider: btn_nav_provider.text = AISidebarI18n.get_text("tab_provider")
	if btn_nav_params: btn_nav_params.text = AISidebarI18n.get_text("tab_parameters")
	if btn_nav_appearance: btn_nav_appearance.text = AISidebarI18n.get_text("tab_appearance")
	if btn_nav_prompt: btn_nav_prompt.text = AISidebarI18n.get_text("tab_system_prompt")
	
	if provider_selector and provider_selector.item_count >= 2:
		provider_selector.set_item_text(0, AISidebarI18n.get_text("provider_antigravity"))
		provider_selector.set_item_text(1, AISidebarI18n.get_text("provider_openai"))
		
	var nav_title = find_child("NavTitle", true, false)
	if nav_title:
		nav_title.text = "Kategoriler" if AISidebarI18n.get_current_language() == "tr" else "Categories"
		
	var temp_hint = find_child("TempHintLabel", true, false)
	if temp_hint:
		temp_hint.text = "Modelin rastlantısallığını belirler. Düşük değerler daha deterministik ve tutarlı kod üretir. Kazara değişimi önlemek için fare tekerleği devre dışıdır." if AISidebarI18n.get_current_language() == "tr" else "Controls model randomness. Lower values produce more consistent code. Mouse wheel is disabled to prevent accidental changes."
		temp_hint.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		temp_hint.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
		
	var max_hint = find_child("MaxIterHint", true, false)
	if max_hint:
		max_hint.text = "Modelin tek bir komut için peş peşe çağırabileceği maksimum araç adım sayısıdır." if AISidebarI18n.get_current_language() == "tr" else "Maximum number of autonomous tool steps allowed per user request."
		max_hint.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		max_hint.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
		
	var lang_hint = find_child("LangHint", true, false)
	if lang_hint:
		lang_hint.text = "Eklenti arayüzünde, onay kartlarında ve sistem bildirimlerinde kullanılan dil." if AISidebarI18n.get_current_language() == "tr" else "Language used across sidebar UI, approval dialogs, and notices."
		lang_hint.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		lang_hint.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
		
	var app_hint = find_child("ApprovalHint", true, false)
	if app_hint:
		app_hint.text = "Dosya yazma ve silme işlemlerinde onay kapısının nasıl davranacağını belirler." if AISidebarI18n.get_current_language() == "tr" else "Controls approval gate behavior for file mutation and deletion."
		app_hint.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		app_hint.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
		
	var prompt_hint = find_child("PromptHint", true, false)
	if prompt_hint:
		prompt_hint.text = AISidebarI18n.get_text("hint_prompt_reset")
		prompt_hint.add_theme_font_size_override("font_size", AISidebarTheme.FONT_SIZE_SMALL)
		prompt_hint.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_MUTED)
		
	if reset_prompt_btn:
		reset_prompt_btn.text = AISidebarI18n.get_text("btn_reset_prompt")
	if reset_temp_btn:
		reset_temp_btn.text = "0.20'ye Sıfırla" if AISidebarI18n.get_current_language() == "tr" else "Reset to 0.20"

func open_settings() -> void:
	_setup_nav()
	_setup_options()
	_setup_temp()
	_apply_styles()
	update_labels()
	_select_category(0)
	
	var config = AISidebarConfig.load_config()
	var current_prov = config.get("provider_type", "antigravity_cli")
	
	if provider_selector:
		provider_selector.selected = 1 if current_prov == "openai_compatible" else 0
		_apply_provider_ui_state(provider_selector.selected)
		
	if base_url_line:
		base_url_line.text = config.get("base_url", "http://localhost:20128/v1")
	if api_key_line:
		api_key_line.text = config.get("api_key", "")
	if temp_slider:
		temp_slider.value = config.get("temperature", 0.20)
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
			
	popup_centered(Vector2i(740, 560))

func _on_provider_selected(idx: int) -> void:
	_apply_provider_ui_state(idx)

func _apply_provider_ui_state(idx: int) -> void:
	var is_antigravity = (idx == 0)
	var endpoint_card = find_child("EndpointCard", true, false)
	
	if is_antigravity:
		if endpoint_card:
			endpoint_card.modulate = Color(1, 1, 1, 0.4)
		if base_url_line:
			base_url_line.editable = false
		if api_key_line:
			api_key_line.editable = false
		if provider_hint_label:
			provider_hint_label.text = "Google Antigravity CLI doğrudan yerel oturumu kullanır. 3. taraf proxy/MITM içermez; API Key veya Base URL gerekmez."
			provider_hint_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_SUCCESS)
	else:
		if endpoint_card:
			endpoint_card.modulate = Color(1, 1, 1, 1.0)
		if base_url_line:
			base_url_line.editable = true
		if api_key_line:
			api_key_line.editable = true
		if provider_hint_label:
			provider_hint_label.text = "OpenAI uyumlu yerel veya bulut API endpointi (9Router, Ollama, OpenRouter vb.)."
			provider_hint_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_WARNING)

func _on_temp_changed(val: float) -> void:
	if temp_val_label:
		var snapped_val = snappedf(val, 0.05)
		if is_equal_approx(snapped_val, 0.20):
			temp_val_label.text = "%0.2f (Varsayılan)" % snapped_val
			temp_val_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_SUCCESS)
		elif snapped_val > 0.60:
			temp_val_label.text = "%0.2f (Yüksek Rastlantısallık)" % snapped_val
			temp_val_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_WARNING)
		else:
			temp_val_label.text = "%0.2f" % snapped_val
			temp_val_label.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_PRIMARY)

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
