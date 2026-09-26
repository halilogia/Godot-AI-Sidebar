@tool
extends AcceptDialog
class_name AISidebarHelpDialog

## Başlıktaki Yardım düğmesinin penceresi: kullanım kılavuzunun özeti eklentinin içinde. Slash komut
## listesi komut kaydından (SlashCommandManager) her açılışta üretilir, yani eklenen her komut burada
## kendiliğinden görünür. Ayrıca @ bahsetmeleri, klavye, onay modları, diğer özellikler ve tam
## kılavuzun bağlantısı (docs/USER_GUIDE*.md, GitHub).

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarSettingsUi = preload("res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd")
const AISidebarSlashCommandManager = preload("res://addons/godot_sidebar_ai/core/commands/slash_command_manager.gd")

const GUIDE_URL_TR := "https://github.com/halilogia/Godot-AI-Sidebar/blob/main/docs/USER_GUIDE.md"
const GUIDE_URL_EN := "https://github.com/halilogia/Godot-AI-Sidebar/blob/main/docs/USER_GUIDE.en.md"
const BASE_SIZE := Vector2(760, 640)

var _scroll: ScrollContainer

func _init() -> void:
	name = "HelpDialog"
	exclusive = false

func open_help() -> void:
	_build()
	var scale := maxf(1.0, AISidebarTheme.ui_scale)
	var avail := Vector2(get_tree().root.size) * 0.9
	popup_centered(Vector2i((BASE_SIZE * scale).min(avail)))

func guide_url() -> String:
	return GUIDE_URL_EN if AISidebarI18n.get_current_language() == "en" else GUIDE_URL_TR

## Sayfayı (yeniden) kurar; ağaç dışında da çalışır (testler).
func _build() -> void:
	title = AISidebarI18n.get_text("help_title")
	ok_button_text = AISidebarI18n.get_text("help_close")
	theme = AISidebarSettingsUi.form_theme()
	get_ok_button().theme_type_variation = AISidebarThemeBuilder.PRIMARY_BUTTON
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

	var start := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("help_start_title"), AISidebarI18n.get_text("help_start_hint"))
	for key: String in ["help_start_1", "help_start_2", "help_start_3", "help_start_4"]:
		start.add_child(AISidebarSettingsUi.body_label(AISidebarI18n.get_text(key)))

	var cmds := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("help_commands_title"), AISidebarI18n.get_text("help_commands_hint"))
	var all: Dictionary = AISidebarSlashCommandManager.get_commands()
	var names: Array = all.keys()
	names.sort()
	for n: Variant in names:
		var cmd: Dictionary = all[n]
		_entry(cmds, "/" + str(n), AISidebarSlashCommandManager.describe(cmd) + "\n" + AISidebarI18n.get_text("help_usage", {"usage": AISidebarSlashCommandManager.usage_text(cmd)}))

	var mentions := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("help_mentions_title"), AISidebarI18n.get_text("help_mentions_hint"))
	_entry(mentions, "@res://path/file.gd", AISidebarI18n.get_text("help_mention_file"))
	_entry(mentions, "@Node:Player", AISidebarI18n.get_text("help_mention_node"))
	_entry(mentions, "@rules", AISidebarI18n.get_text("help_mention_rules"))
	_entry(mentions, "@skill:name", AISidebarI18n.get_text("help_mention_skill"))

	var keys := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("help_keys_title"))
	_entry(keys, "Enter", AISidebarI18n.get_text("help_key_enter"))
	_entry(keys, "Shift+Enter", AISidebarI18n.get_text("help_key_newline"))
	_entry(keys, "Ctrl+V", AISidebarI18n.get_text("help_key_paste"))
	_entry(keys, "/  @", AISidebarI18n.get_text("help_key_popup"))
	_entry(keys, "Ctrl+Z", AISidebarI18n.get_text("help_key_undo"))

	var modes := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("help_modes_title"), AISidebarI18n.get_text("help_modes_hint"))
	_entry(modes, AISidebarI18n.get_text("mode_manual"), AISidebarI18n.get_text("mode_manual_desc"))
	_entry(modes, AISidebarI18n.get_text("mode_auto"), AISidebarI18n.get_text("mode_auto_desc"))
	_entry(modes, AISidebarI18n.get_text("mode_full_auto"), AISidebarI18n.get_text("mode_full_auto_desc"))

	var more := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("help_more_title"))
	for key: String in ["help_more_resume", "help_more_queue", "help_more_goal", "help_more_rules", "help_more_history", "help_more_mcp"]:
		more.add_child(AISidebarSettingsUi.body_label(AISidebarI18n.get_text(key)))

	var guide := AISidebarSettingsUi.card(page, AISidebarI18n.get_text("help_guide_title"), AISidebarI18n.get_text("help_guide_hint"))
	var row := AISidebarSettingsUi.row(guide)
	row.add_child(AISidebarSettingsUi.primary_button(AISidebarI18n.get_text("help_guide_open"), func() -> void: OS.shell_open(guide_url())))
	row.add_child(AISidebarSettingsUi.spacer())

## "Anahtar — açıklama" satırı: sol sütunda komut / kısayol (rozet), sağda açıklama.
func _entry(parent: Control, key_text: String, desc: String) -> void:
	var r := AISidebarSettingsUi.row(parent)
	var k := AISidebarSettingsUi.badge(key_text, AISidebarTheme.COLOR_ACCENT)
	k.custom_minimum_size = Vector2(float(AISidebarSettingsUi.base_size) * 8.0, 0)
	k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	k.clip_text = true
	k.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	k.tooltip_text = key_text
	r.add_child(k)
	var d := AISidebarSettingsUi.hint_label(desc)
	r.add_child(d)

## Testler için: kurulu sayfadaki bütün metinler.
func collect_texts() -> Array[String]:
	var out: Array[String] = []
	_collect(self, out)
	return out

func _collect(n: Node, out: Array[String]) -> void:
	if n is Label:
		var l: Label = n
		out.append(l.text)
	for c: Node in n.get_children():
		_collect(c, out)
