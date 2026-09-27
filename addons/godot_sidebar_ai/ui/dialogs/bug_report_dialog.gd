@tool
extends AcceptDialog
class_name AISidebarBugReportDialog

## Hata bildirme penceresi (Yardım, Ayarlar → Genel, `/bug`). Kullanıcı ne olduğunu yazar, rapora neyin
## gireceğini seçer; "Raporu oluştur" yerel bir zip yazar (AISidebarBugReport). Sonra klasörü açabilir,
## issue metnini kopyalayabilir ya da GitHub'ın yeni issue sayfasını açabilir. Hiçbir şey kendiliğinden
## gönderilmez.

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarSettingsUi = preload("res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd")
const AISidebarBugReport = preload("res://addons/godot_sidebar_ai/core/diagnostics/bug_report.gd")

const BASE_SIZE := Vector2(680, 600)

var description_edit: TextEdit
var chat_check: CheckBox
var screenshot_check: CheckBox
var log_check: CheckBox
var create_btn: Button
var result_box: VBoxContainer
var result_label: Label
var last_result: Dictionary = {}

var _scroll: ScrollContainer
## Açılışta panelden alınan veriler: {"chat_md", "screenshot", "env_extra", "last_task"}; araçlar için
## isteğe bağlı "out_dir" ve "clipboard" (false: issue metni panoya kopyalanmaz).
var _context: Dictionary = {}

func _init() -> void:
	name = "BugReportDialog"
	exclusive = false

## `context` açılış anında panelden alınır (görüntü pencere açılmadan çekilir).
func open_report(context: Dictionary) -> void:
	_context = context
	_build()
	var scale := maxf(1.0, AISidebarTheme.ui_scale)
	var avail := Vector2(get_tree().root.size) * 0.9
	popup_centered(Vector2i((BASE_SIZE * scale).min(avail)))
	description_edit.grab_focus()

## Sayfayı (yeniden) kurar; ağaç dışında da çalışır (testler).
func _build() -> void:
	title = AISidebarI18n.get_text("bug_title")
	ok_button_text = AISidebarI18n.get_text("help_close")
	theme = AISidebarSettingsUi.form_theme()
	get_ok_button().theme_type_variation = AISidebarThemeBuilder.BUTTON
	last_result = {}
	if _scroll != null:
		_scroll.queue_free()
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", AISidebarTheme.px(AISidebarTheme.SPACE_MD))
	_scroll.add_child(gutter)
	var page := AISidebarSettingsUi.page()
	gutter.add_child(page)

	var what := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("bug_what_title"), AISidebarI18n.get_text("bug_what_hint"))
	description_edit = TextEdit.new()
	description_edit.placeholder_text = AISidebarI18n.get_text("bug_what_placeholder")
	description_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description_edit.custom_minimum_size = Vector2(0, float(AISidebarSettingsUi.base_size) * 9.0)
	description_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AISidebarSettingsUi.style_input(description_edit)
	what.add_child(description_edit)

	var parts := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("bug_parts_title"), AISidebarI18n.get_text("bug_parts_hint"))
	chat_check = _check(parts, "bug_part_chat", not str(_context.get("chat_md", "")).is_empty())
	screenshot_check = _check(parts, "bug_part_screenshot", _context.get("screenshot", null) is Image)
	log_check = _check(parts, "bug_part_log", true)
	var row := AISidebarSettingsUi.row(parts)
	row.add_child(AISidebarSettingsUi.spacer())
	create_btn = AISidebarSettingsUi.primary_button(AISidebarI18n.get_text("bug_create"), create_report)
	row.add_child(create_btn)

	result_box = AISidebarSettingsUi.card(page, AISidebarI18n.get_text("bug_result_title"), AISidebarI18n.get_text("bug_result_hint"))
	result_label = AISidebarSettingsUi.status_label()
	result_box.add_child(result_label)
	var actions := AISidebarSettingsUi.row(result_box)
	actions.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("bug_open_folder"), func() -> void: OS.shell_open(str(last_result.get("path", "")).get_base_dir())))
	actions.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("bug_copy_text"), func() -> void: DisplayServer.clipboard_set(str(last_result.get("markdown", "")))))
	actions.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("bug_open_issue"), func() -> void: OS.shell_open(AISidebarBugReport.ISSUES_URL)))
	actions.add_child(AISidebarSettingsUi.spacer())
	# Kart ancak rapor oluşunca görünür (içindeki düğmelerin işleyeceği bir dosya olsun).
	(result_box.get_parent() as Control).visible = false

func _check(parent: Control, key: String, available: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = AISidebarI18n.get_text(key)
	c.button_pressed = available
	c.disabled = not available
	parent.add_child(c)
	return c

## Raporu yazar; sonucu kartta gösterir. Testler doğrudan çağırır.
func create_report() -> Dictionary:
	var parts := {
		"chat_md": str(_context.get("chat_md", "")) if chat_check.button_pressed else "",
		"screenshot": _context.get("screenshot", null) if screenshot_check.button_pressed else null,
		"include_log": log_check.button_pressed,
	}
	var env_extra: Dictionary = _context.get("env_extra", {})
	var last_task: Dictionary = _context.get("last_task", {})
	var env := AISidebarBugReport.environment(env_extra)
	var out_dir: String = _context.get("out_dir", AISidebarBugReport.OUT_DIR)
	last_result = AISidebarBugReport.build(description_edit.text, env, last_task, parts, out_dir)
	(result_box.get_parent() as Control).visible = true
	if last_result.get("ok", false) == true:
		if _context.get("clipboard", true) == true:
			DisplayServer.clipboard_set(str(last_result.get("markdown", "")))
		AISidebarSettingsUi.set_status(result_label, AISidebarI18n.get_text("bug_created", {"path": str(last_result.get("path", ""))}))
	else:
		AISidebarSettingsUi.set_status(result_label, AISidebarI18n.get_text("bug_failed", {"error": str(last_result.get("error", ""))}), true)
	return last_result
