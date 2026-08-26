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

func _ready() -> void:
	title = AISidebarI18n.get_text("settings_title")
	ok_button_text = AISidebarI18n.get_text("btn_save_close")
	
	if not confirmed.is_connected(_on_confirmed):
		confirmed.connect(_on_confirmed)
	if temp_slider and not temp_slider.value_changed.is_connected(_on_temp_changed):
		temp_slider.value_changed.connect(_on_temp_changed)
		
	update_labels()

func update_labels() -> void:
	title = AISidebarI18n.get_text("settings_title")
	ok_button_text = AISidebarI18n.get_text("btn_save_close")
	
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
	update_labels()
	var config = AISidebarConfig.load_config()
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
		
	popup_centered(Vector2i(550, 480))

func _on_temp_changed(val: float) -> void:
	if temp_val_label:
		temp_val_label.text = str(snappedf(val, 0.05))

func _on_confirmed() -> void:
	var config = AISidebarConfig.load_config()
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
