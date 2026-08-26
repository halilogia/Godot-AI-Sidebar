@tool
extends PanelContainer
class_name AISidebarTelemetryCard

## Minimal Görev Tamamlama ve Telemetri Kartı (Telemetry Footer Card) (SRP).
## Ana görünümde temiz tek satır özet, tıklandığında detaylı süre dökümü sunar.

var metrics: Dictionary = {}
var is_expanded: bool = false

var _vbox: VBoxContainer
var _header_btn: Button
var _details_lbl: RichTextLabel

func _init(p_metrics: Dictionary = {}) -> void:
	metrics = p_metrics

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_ui()
	if not metrics.is_empty():
		render_metrics(metrics)

func _setup_ui() -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.bg_color = Color(0.10, 0.12, 0.15, 0.7)
	style.border_color = Color(0.2, 0.25, 0.3, 0.3)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_top = 4
	style.content_margin_right = 8
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 2)
	add_child(_vbox)
	
	_header_btn = Button.new()
	_header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_btn.flat = true
	_header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_btn.focus_mode = Control.FOCUS_NONE
	_header_btn.add_theme_font_size_override("font_size", 10)
	_header_btn.pressed.connect(_on_header_pressed)
	_vbox.add_child(_header_btn)
	
	_details_lbl = RichTextLabel.new()
	_details_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_lbl.bbcode_enabled = true
	_details_lbl.fit_content = true
	_details_lbl.scroll_active = false
	_details_lbl.selection_enabled = true
	_details_lbl.add_theme_font_size_override("normal_font_size", 10)
	_details_lbl.visible = is_expanded
	_vbox.add_child(_details_lbl)

func render_metrics(m: Dictionary) -> void:
	metrics = m
	if not _header_btn or not _details_lbl:
		return
		
	var is_ok = m.get("success", true)
	var elapsed = str(m.get("elapsed_seconds", 0.0)) + "s"
	var turns = str(m.get("llm_turns", 1))
	var tools = str(m.get("tool_calls", 0))
	var files = str(m.get("file_ops", 0))
	
	var icon = "✓" if is_ok else "✕"
	var color_name = "#a3be8c" if is_ok else "#bf616a"
	
	_header_btn.text = icon + " Completed in " + elapsed + " · " + turns + " LLM turns · " + tools + " tools · " + files + " files"
	_header_btn.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	
	var llm_s = str(m.get("llm_time_s", 0.0)) + "s"
	var tool_s = str(m.get("tool_time_s", 0.0)) + "s"
	var file_s = str(m.get("file_time_s", 0.0)) + "s"
	var wait_s = str(m.get("waiting_time_s", 0.0)) + "s"
	
	_details_lbl.text = "[color=#717c91]• Breakdown: LLM: " + llm_s + " | Tools: " + tool_s + " (File: " + file_s + ") | Waiting: " + wait_s + "[/color]"

func _on_header_pressed() -> void:
	is_expanded = not is_expanded
	if _details_lbl:
		_details_lbl.visible = is_expanded
