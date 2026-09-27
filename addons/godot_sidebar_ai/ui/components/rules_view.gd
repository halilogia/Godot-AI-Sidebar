@tool
extends VBoxContainer
class_name AISidebarRulesView

## Ayarlar → Kurallar: modelin her turda aldığı talimat katmanları tek sayfada.
##   Bağlam yükü: sistem istemi / kurallar / skill'ler / araçlar için yaklaşık token payı
##   Yerleşik kurallar: eklentinin sistem istemi (düzenlenir, varsayılana döner; config "system_prompt")
##   Global ve proje kuralları: bulunan dosyalar, aç / oluştur, tek satırlık kural ekle (/learn ile aynı)
## Sistem istemi burada düzenlenir; "Kaydet ve Kapat"ta pencere prompt_text() ile config'e yazar.

const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarContextBudget = preload("res://addons/godot_sidebar_ai/core/agent/context_budget.gd")
const AISidebarCustomizationBudget = preload("res://addons/godot_sidebar_ai/core/skills/customization_budget.gd")
const AISidebarRulesRegistry = preload("res://addons/godot_sidebar_ai/core/skills/rules_registry.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarSettingsUi = preload("res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd")


var prompt_edit: TextEdit
var _prompt_badge: Label
var _prompt_size: Label
var _bar: HBoxContainer
var _legend: GridContainer
var _total_badge: Label
var _rules_list: VBoxContainer
var _rule_edit: LineEdit
var _rule_scope: OptionButton
var _status: Label

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_MD))

	_total_badge = AISidebarSettingsUi.badge("", AISidebarThemeBuilder.TONE_ACCENT)
	var usage := AISidebarSettingsUi.card(self, AISidebarI18n.get_text("custom_usage_title"), AISidebarI18n.get_text("custom_usage_hint"), _total_badge)
	# Bölümlü çubuk: her katman yuvarlak uçlu ayrı bir bölüm, aralarında boşluk.
	_bar = HBoxContainer.new()
	_bar.custom_minimum_size = Vector2(0, AISidebarTheme.px(AISidebarTheme.SPACE_SM + 2))
	_bar.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_XXS + 1))
	usage.add_child(_bar)
	# Açıklama: renk noktası + ad (sol), değer (sağ); iki sütun.
	_legend = GridContainer.new()
	_legend.columns = 2
	_legend.add_theme_constant_override("h_separation", AISidebarTheme.px(AISidebarTheme.SPACE_LG))
	_legend.add_theme_constant_override("v_separation", AISidebarTheme.px(AISidebarTheme.SPACE_XS))
	usage.add_child(_legend)

	_prompt_badge = AISidebarSettingsUi.badge("", AISidebarThemeBuilder.TONE_LAYER_SYSTEM)
	var builtin := AISidebarSettingsUi.card(self, AISidebarI18n.get_text("rules_builtin_title"), AISidebarI18n.get_text("rules_builtin_hint"), _prompt_badge)
	prompt_edit = TextEdit.new()
	prompt_edit.name = "SysPromptEdit"
	prompt_edit.custom_minimum_size = Vector2(0, float(AISidebarSettingsUi.base_size) * 16.0)
	prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	AISidebarSettingsUi.style_input(prompt_edit)
	prompt_edit.text_changed.connect(_update_prompt_state)
	builtin.add_child(prompt_edit)
	var prompt_row := AISidebarSettingsUi.row(builtin)
	_prompt_size = AISidebarSettingsUi.hint_label("")
	prompt_row.add_child(_prompt_size)
	prompt_row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("btn_reset_prompt"), _on_reset_prompt))

	var files := AISidebarSettingsUi.card(self, AISidebarI18n.get_text("rules_files_title"), AISidebarI18n.get_text("custom_rules_hint"))
	_rules_list = VBoxContainer.new()
	_rules_list.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_XS))
	files.add_child(_rules_list)
	var open_row := AISidebarSettingsUi.row(files)
	open_row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("custom_open_project_rules"), func() -> void: _open_rule_file(AISidebarRulesRegistry.PROJECT_LEARN_FILE)))
	open_row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("custom_open_global_rules"), func() -> void: _open_rule_file(AISidebarRulesRegistry.global_dir().path_join("AGENTS.md"))))
	var add_row := AISidebarSettingsUi.row(files)
	_rule_edit = AISidebarSettingsUi.line_edit(AISidebarI18n.get_text("custom_rule_placeholder"))
	_rule_edit.text_submitted.connect(func(_t: String) -> void: _on_add_rule())
	add_row.add_child(_rule_edit)
	_rule_scope = AISidebarSettingsUi.option_button()
	_rule_scope.custom_minimum_size = Vector2(float(AISidebarSettingsUi.base_size) * 7.0, 0)
	_rule_scope.add_item(AISidebarI18n.get_text("custom_scope_project"), 0)
	_rule_scope.add_item(AISidebarI18n.get_text("custom_scope_global"), 1)
	add_row.add_child(_rule_scope)
	add_row.add_child(AISidebarSettingsUi.primary_button(AISidebarI18n.get_text("custom_add_rule"), _on_add_rule))
	_status = AISidebarSettingsUi.status_label()
	files.add_child(_status)

func load_from(cfg: Dictionary) -> void:
	prompt_edit.text = str(cfg.get("system_prompt", ""))
	_update_prompt_state()
	AISidebarSettingsUi.set_status(_status, "")

func prompt_text() -> String:
	return prompt_edit.text

func refresh() -> void:
	_refresh_usage()
	_refresh_rules()

func _update_prompt_state() -> void:
	var text := prompt_edit.text
	var is_default := text == str(AISidebarConfig.DEFAULT_CONFIG.get("system_prompt", ""))
	if is_default:
		AISidebarSettingsUi.set_badge(_prompt_badge, AISidebarI18n.get_text("rules_builtin_default"), AISidebarThemeBuilder.TONE_SUCCESS)
	else:
		AISidebarSettingsUi.set_badge(_prompt_badge, AISidebarI18n.get_text("rules_builtin_custom"), AISidebarThemeBuilder.TONE_WARNING)
	_prompt_size.text = AISidebarI18n.get_text("rules_builtin_size", {"chars": text.length(), "tokens": ceili(text.length() / 4.0)})

func _on_reset_prompt() -> void:
	prompt_edit.text = str(AISidebarConfig.DEFAULT_CONFIG.get("system_prompt", ""))
	_update_prompt_state()

func _refresh_usage() -> void:
	for c: Node in _bar.get_children():
		c.queue_free()
	for c: Node in _legend.get_children():
		c.queue_free()
	var m := AISidebarCustomizationBudget.measure()
	var total_tokens: int = m["total_tokens"]
	var total: int = maxi(1, total_tokens)
	AISidebarSettingsUi.set_badge(_total_badge, AISidebarI18n.get_text("custom_usage_total", {"tokens": AISidebarContextBudget.short(total_tokens)}), AISidebarThemeBuilder.TONE_ACCENT)
	var rows := [["system", AISidebarThemeBuilder.TONE_LAYER_SYSTEM, "custom_usage_system"], ["rules", AISidebarThemeBuilder.TONE_LAYER_RULES, "custom_usage_rules"], ["skills", AISidebarThemeBuilder.TONE_LAYER_SKILLS, "custom_usage_skills"], ["tools", AISidebarThemeBuilder.TONE_LAYER_TOOLS, "custom_usage_tools"]]
	for row: Array in rows:
		var part: Dictionary = m[row[0]]
		var tokens: int = part["tokens"]
		var tone: String = row[1]
		var key: String = row[2]
		var count: int = part.get("count", part.get("files", 0))
		if tokens > 0:
			var seg := PanelContainer.new()
			seg.theme_type_variation = AISidebarThemeBuilder.segment(tone)
			seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			seg.size_flags_stretch_ratio = float(tokens)
			# Çok küçük katman da görünsün (ince çizgi değil, en az bir nokta genişliği).
			seg.custom_minimum_size = Vector2(AISidebarTheme.px(AISidebarTheme.SPACE_SM), 0)
			seg.tooltip_text = AISidebarI18n.get_text(key, {"count": count})
			_bar.add_child(seg)
		_legend.add_child(_legend_cell(tone, AISidebarI18n.get_text(key, {"count": count}), AISidebarI18n.get_text("custom_usage_value", {"percent": "%.1f" % (100.0 * tokens / total), "tokens": tokens})))
	var rules_d: Dictionary = m["rules"]
	if rules_d.get("truncated", false) == true:
		var warn := AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("custom_rules_truncated", {"max": AISidebarRulesRegistry.MAX_TOTAL_CHARS}))
		warn.add_theme_color_override("font_color", AISidebarTheme.COLOR_WARNING)
		_legend.add_child(warn)

## Açıklama hücresi: renk noktası, katmanın adı ve sağa hizalı "~N token · %P".
func _legend_cell(tone: String, name_text: String, value_text: String) -> HBoxContainer:
	var cell := HBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	var dot := PanelContainer.new()
	dot.theme_type_variation = AISidebarThemeBuilder.segment(tone)
	dot.custom_minimum_size = Vector2(AISidebarTheme.px(AISidebarTheme.SPACE_SM), AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(dot)
	var name_label := Label.new()
	name_label.text = name_text
	name_label.tooltip_text = name_text
	name_label.theme_type_variation = AISidebarThemeBuilder.LABEL_SMALL
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cell.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value_text
	value_label.theme_type_variation = AISidebarThemeBuilder.HINT_MUTED
	cell.add_child(value_label)
	return cell

func _refresh_rules() -> void:
	for c: Node in _rules_list.get_children():
		c.queue_free()
	var files := AISidebarRulesRegistry.discover()
	if files.is_empty():
		_rules_list.add_child(AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("custom_rules_none")))
		return
	for f: Dictionary in files:
		var row := AISidebarSettingsUi.row(_rules_list)
		if str(f["scope"]) == AISidebarRulesRegistry.SCOPE_GLOBAL:
			row.add_child(AISidebarSettingsUi.badge(AISidebarI18n.get_text("custom_scope_global"), AISidebarThemeBuilder.TONE_LAYER_TOOLS))
		else:
			row.add_child(AISidebarSettingsUi.badge(AISidebarI18n.get_text("custom_scope_project"), AISidebarThemeBuilder.TONE_LAYER_RULES))
		var chars: int = f["chars"]
		var p := str(f["path"])
		var path := AISidebarSettingsUi.body_label(AISidebarI18n.get_text("custom_rule_file", {"path": p, "chars": chars}))
		path.autowrap_mode = TextServer.AUTOWRAP_OFF
		path.clip_text = true
		path.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		path.tooltip_text = p
		row.add_child(path)
		row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("custom_show_in_folder"), func() -> void: OS.shell_show_in_file_manager(ProjectSettings.globalize_path(p))))

func _open_rule_file(path: String) -> void:
	if path.is_empty():
		return
	var res := AISidebarRulesRegistry.ensure_file(path)
	if res.get("ok", false) == true:
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(path))
	else:
		AISidebarSettingsUi.set_status(_status, AISidebarI18n.get_text("skills_error", {"error": str(res.get("error", ""))}), true)
	refresh()

func _on_add_rule() -> void:
	var scope := AISidebarRulesRegistry.SCOPE_GLOBAL if _rule_scope.selected == 1 else AISidebarRulesRegistry.SCOPE_PROJECT
	var res := AISidebarRulesRegistry.add_rule(_rule_edit.text, scope)
	if res.get("ok", false) == true:
		_rule_edit.clear()
		AISidebarSettingsUi.set_status(_status, AISidebarI18n.get_text("custom_rule_added", {"path": str(res["path"])}))
	else:
		AISidebarSettingsUi.set_status(_status, AISidebarI18n.get_text("skills_error", {"error": str(res.get("error", ""))}), true)
	refresh()
