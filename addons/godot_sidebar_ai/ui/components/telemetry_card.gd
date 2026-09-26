@tool
extends PanelContainer
class_name AISidebarTelemetryCard

## Minimal Görev Tamamlama ve Telemetri Kartı (Telemetry Footer Card) (SRP).
## Ana görünümde temiz tek satır özet (Adım / Max Adım dahil), tıklandığında detaylı süre dökümü sunar.

signal copy_task_requested(task_id: String)

const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
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
	theme_type_variation = AISidebarThemeBuilder.CARD_SUBTLE
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_vbox.add_theme_constant_override("separation", AISidebarTheme.px(2))
	add_child(_vbox)
	
	_header_bar = HBoxContainer.new()
	_header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_header_bar.add_theme_constant_override("separation", AISidebarTheme.px(2))
	_vbox.add_child(_header_bar)

	_header_btn = Button.new()
	_header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_btn.flat = true
	_header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_btn.focus_mode = Control.FOCUS_NONE  # focus: akıştaki açılır özet; tıklamak yazma odağını almasın
	# Tek satır: dar dock'ta "…" ile kesilir, tam metin tooltip'te.
	_header_btn.clip_text = true
	_header_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header_btn.theme_type_variation = AISidebarThemeBuilder.LINK_BUTTON
	_header_btn.pressed.connect(_on_header_pressed)
	_header_bar.add_child(_header_btn)

	_copy_btn = Button.new()
	_copy_btn.flat = true
	_copy_btn.focus_mode = Control.FOCUS_ALL
	_copy_btn.tooltip_text = AISidebarI18n.get_text("telemetry_copy_tooltip")
	_copy_btn.theme_type_variation = AISidebarThemeBuilder.LINK_BUTTON
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
	_details_lbl.theme_type_variation = AISidebarThemeBuilder.RICH_SMALL
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
		AISidebarIconHelper.apply_tinted_icon(_header_btn, "check", AISidebarTheme.COLOR_SUCCESS, AISidebarTheme.ICON_SIZE_SM)
	elif completion == "incomplete":
		_header_btn.text = AISidebarI18n.get_text("telemetry_needs_review", {"elapsed": elapsed, "summary": summary})
		AISidebarIconHelper.apply_tinted_icon(_header_btn, "triangle-alert", AISidebarTheme.COLOR_WARNING, AISidebarTheme.ICON_SIZE_SM)
	else:
		_header_btn.text = AISidebarI18n.get_text("telemetry_failed", {"elapsed": elapsed, "summary": summary})
		AISidebarIconHelper.apply_tinted_icon(_header_btn, "x", AISidebarTheme.COLOR_ERROR, AISidebarTheme.ICON_SIZE_SM)
	_header_btn.tooltip_text = _header_btn.text
	_header_btn.add_theme_color_override("font_color", AISidebarTheme.COLOR_TEXT_SECONDARY)
	
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

	_details_lbl.text = "[color=" + AISidebarTheme.bb(AISidebarTheme.COLOR_TEXT_MUTED) + "]• Steps: " + str(used_steps) + " used / " + str(max_steps) + " safety limit" + limit_txt + " | Active Tools: " + tools_sent + " sent / " + total_tools + " total | LLM: " + llm_s + " | Tools: " + tool_s + " (File: " + file_s + ") | Waiting: " + wait_s + "[/color]\n[color=" + AISidebarTheme.bb(AISidebarTheme.COLOR_TEXT_MUTED) + "]• Research: " + research_s + " (overhead " + overhead_txt + ") | Ops " + rsw + " | Failed: " + failed_txt + " | Retries: " + retry_txt + " | Files: " + files_txt + "[/color]"  # i18n-ignore: teknik metrik dökümü; adlar export / build_metrics anahtarlarıyla aynı, iki dilde İngilizce kalır

func _on_header_pressed() -> void:
	is_expanded = not is_expanded
	if _details_lbl:
		_details_lbl.visible = is_expanded
