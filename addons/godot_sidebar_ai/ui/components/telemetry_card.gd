@tool
extends PanelContainer
class_name AISidebarTelemetryCard

## Minimal Görev Tamamlama ve Telemetri Kartı (Telemetry Footer Card) (SRP).
## Ana görünümde temiz tek satır özet (Adım / Max Adım dahil), tıklandığında detaylı süre dökümü sunar.

signal copy_task_requested(task_id: String)

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

var metrics: Dictionary = {}
var is_expanded: bool = false
## İlgili transcript task'ı (boşsa Copy gizlenir; örn. restore edilen kartlar).
var task_id: String = ""

var _vbox: VBoxContainer
var _header_bar: HBoxContainer
var _header_btn: Button
var _copy_btn: Button
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
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override("panel", style)
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_theme_constant_override("separation", 2)
	add_child(_vbox)
	
	_header_bar = HBoxContainer.new()
	_header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_header_bar.add_theme_constant_override("separation", 2)
	_vbox.add_child(_header_bar)

	_header_btn = Button.new()
	_header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_btn.flat = true
	_header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_btn.focus_mode = Control.FOCUS_NONE
	# Tek satır: dar dock'ta "…" ile kesilir, tam metin tooltip'te.
	_header_btn.clip_text = true
	_header_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header_btn.add_theme_font_size_override("font_size", 10)
	_header_btn.pressed.connect(_on_header_pressed)
	_header_bar.add_child(_header_btn)

	_copy_btn = Button.new()
	_copy_btn.flat = true
	_copy_btn.focus_mode = Control.FOCUS_NONE
	_copy_btn.tooltip_text = AISidebarI18n.get_text("telemetry_copy_tooltip")
	_copy_btn.add_theme_font_size_override("font_size", 10)
	_copy_btn.text = AISidebarI18n.get_text("btn_copy")
	_copy_btn.visible = not task_id.strip_edges().is_empty()
	_copy_btn.pressed.connect(func(): copy_task_requested.emit(task_id))
	_header_bar.add_child(_copy_btn)
	
	_details_lbl = RichTextLabel.new()
	_details_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_lbl.bbcode_enabled = true
	_details_lbl.fit_content = true
	_details_lbl.scroll_active = false
	_details_lbl.selection_enabled = true
	_details_lbl.context_menu_enabled = true
	_details_lbl.shortcut_keys_enabled = true
	_details_lbl.focus_mode = Control.FOCUS_CLICK
	_details_lbl.deselect_on_focus_loss_enabled = false
	_details_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	_details_lbl.add_theme_font_size_override("normal_font_size", 10)
	_details_lbl.visible = is_expanded
	_vbox.add_child(_details_lbl)

func render_metrics(m: Dictionary) -> void:
	metrics = m
	if _copy_btn:
		_copy_btn.visible = not task_id.strip_edges().is_empty()
	if not _header_btn or not _details_lbl:
		return
		
	var is_ok = m.get("success", true)
	var elapsed = str(m.get("elapsed_seconds", 0.0)) + "s"
	var used_steps = m.get("used_steps", m.get("llm_turns", 1))
	var max_steps = m.get("max_steps", 20)
	var tools_executed = str(m.get("tool_calls", 0))
	var tools_sent = str(m.get("tools_sent", 0))
	var total_tools = str(m.get("total_tools", 34))
	var files = str(m.get("file_ops", 0))
	
	var completion = str(m.get("completion", "success" if is_ok else "failed"))
	var summary = "Steps: " + str(used_steps) + "/" + str(max_steps) + " · Tools: " + tools_sent + "/" + total_tools + " active (" + tools_executed + " used) · " + files + " files"
	if is_ok and completion == "success":
		_header_btn.text = AISidebarI18n.get_text("telemetry_completed", {"elapsed": elapsed, "summary": summary})
		AISidebarIconHelper.apply_tinted_icon(_header_btn, "check", AISidebarTheme.COLOR_SUCCESS, 12)
	elif completion == "incomplete":
		_header_btn.text = AISidebarI18n.get_text("telemetry_needs_review", {"elapsed": elapsed, "summary": summary})
		AISidebarIconHelper.apply_tinted_icon(_header_btn, "triangle-alert", AISidebarTheme.COLOR_WARNING, 12)
	else:
		_header_btn.text = AISidebarI18n.get_text("telemetry_failed", {"elapsed": elapsed, "summary": summary})
		AISidebarIconHelper.apply_tinted_icon(_header_btn, "x", AISidebarTheme.COLOR_ERROR, 12)
	_header_btn.tooltip_text = _header_btn.text
	_header_btn.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	
	var llm_s = str(m.get("llm_time_s", 0.0)) + "s"
	var tool_s = str(m.get("tool_time_s", 0.0)) + "s"
	var file_s = str(m.get("file_time_s", 0.0)) + "s"
	var wait_s = str(m.get("waiting_time_s", 0.0)) + "s"
	var research_s = str(m.get("research_time_s", 0.0)) + "s"
	var overhead = m.get("research_overhead_ratio", null)
	var overhead_txt = ("%.0f%%" % (float(overhead) * 100.0)) if overhead != null else "n/a"
	var rsw = "R:%s/S:%s/W:%s" % [str(m.get("read_ops", 0)), str(m.get("search_ops", 0)), str(m.get("write_ops", 0))]
	var failed_txt = str(m.get("failed_tools", 0))
	var retry_txt = str(m.get("retry_count", 0))
	var files_txt = "%s read / %s written" % [str(m.get("files_read_count", 0)), str(m.get("files_written_count", 0))]
	var limit_txt = " · LIMIT" if bool(m.get("limit_hit", false)) else ""

	_details_lbl.text = "[color=#717c91]• Steps: " + str(used_steps) + " used / " + str(max_steps) + " safety limit" + limit_txt + " | Active Tools: " + tools_sent + " sent / " + total_tools + " total | LLM: " + llm_s + " | Tools: " + tool_s + " (File: " + file_s + ") | Waiting: " + wait_s + "[/color]\n[color=#717c91]• Research: " + research_s + " (overhead " + overhead_txt + ") | Ops " + rsw + " | Failed: " + failed_txt + " | Retries: " + retry_txt + " | Files: " + files_txt + "[/color]"  # i18n-ignore: teknik metrik dökümü; adlar export / build_metrics anahtarlarıyla aynı, iki dilde İngilizce kalır

func _on_header_pressed() -> void:
	is_expanded = not is_expanded
	if _details_lbl:
		_details_lbl.visible = is_expanded
