@tool
extends VBoxContainer
class_name AISidebarCustomizationsView

## Ayarlar → Özelleştirmeler: token kullanımı (kurallar / skill'ler / araçlar), kurallar (global ve proje
## dosyaları, aç / oluştur, kural ekle) ve skill yönetimi (AISidebarSkillsView). Sistem istemi eklentinin
## kendi davranışıdır (Ayarlar → Sistem Promptu); kurallar onun üstüne eklenir.

const AISidebarCustomizationBudget = preload("res://addons/godot_sidebar_ai/core/skills/customization_budget.gd")
const AISidebarRulesRegistry = preload("res://addons/godot_sidebar_ai/core/skills/rules_registry.gd")
const AISidebarSkillsView = preload("res://addons/godot_sidebar_ai/ui/components/skills_view.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

const COLOR_SYSTEM := Color(0.95, 0.75, 0.35)
const COLOR_RULES := Color(0.35, 0.6, 0.95)

## Kullanıcı yerleşik katmanın (sistem istemi) "Düzenle" düğmesine bastı; Ayarlar Sistem Promptu sayfasını açar.
signal edit_system_prompt_requested
const COLOR_SKILLS := Color(0.45, 0.8, 0.5)
const COLOR_TOOLS := Color(0.7, 0.5, 0.9)

var skills_view: AISidebarSkillsView
var _bar: HBoxContainer
var _legend: VBoxContainer
var _rules_list: VBoxContainer
var _rule_edit: LineEdit
var _rule_scope: OptionButton
var _status: Label

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	_section("custom_usage_title")
	_small("custom_usage_hint")
	_bar = HBoxContainer.new()
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.add_theme_constant_override("separation", 0)
	add_child(_bar)
	_legend = VBoxContainer.new()
	add_child(_legend)

	_section("custom_rules_title")
	_small("custom_rules_hint")
	_rules_list = VBoxContainer.new()
	add_child(_rules_list)
	var open_row := HBoxContainer.new()
	add_child(open_row)
	open_row.add_child(_button("custom_open_project_rules", func() -> void: _open_rule_file(AISidebarRulesRegistry.PROJECT_LEARN_FILE)))
	open_row.add_child(_button("custom_open_global_rules", func() -> void: _open_rule_file(AISidebarRulesRegistry.global_dir().path_join("AGENTS.md"))))
	var add_row := HBoxContainer.new()
	add_child(add_row)
	_rule_edit = LineEdit.new()
	_rule_edit.placeholder_text = AISidebarI18n.get_text("custom_rule_placeholder")
	_rule_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(_rule_edit)
	_rule_scope = OptionButton.new()
	_rule_scope.add_item(AISidebarI18n.get_text("custom_scope_project"), 0)
	_rule_scope.add_item(AISidebarI18n.get_text("custom_scope_global"), 1)
	add_row.add_child(_rule_scope)
	add_row.add_child(_button("custom_add_rule", _on_add_rule))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	add_child(_status)

	_section("custom_skills_title")
	skills_view = AISidebarSkillsView.new()
	add_child(skills_view)
	refresh()

func _section(key: String) -> void:
	var l := Label.new()
	l.text = AISidebarI18n.get_text(key)
	l.add_theme_font_size_override("font_size", 14)
	add_child(l)

func _small(key: String) -> void:
	var l := Label.new()
	l.text = AISidebarI18n.get_text(key)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 11)
	l.modulate = Color(1, 1, 1, 0.75)
	add_child(l)

func _button(key: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = AISidebarI18n.get_text(key)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b

func refresh() -> void:
	if _bar == null:
		return
	_refresh_usage()
	_refresh_rules()
	if skills_view:
		skills_view.refresh()

func _refresh_usage() -> void:
	for c: Node in _bar.get_children():
		c.queue_free()
	for c: Node in _legend.get_children():
		c.queue_free()
	var m := AISidebarCustomizationBudget.measure()
	var total_tokens: int = m["total_tokens"]
	var total: int = maxi(1, total_tokens)
	var rows := [["system", COLOR_SYSTEM, "custom_usage_system"], ["rules", COLOR_RULES, "custom_usage_rules"], ["skills", COLOR_SKILLS, "custom_usage_skills"], ["tools", COLOR_TOOLS, "custom_usage_tools"]]
	for row: Array in rows:
		var part: Dictionary = m[row[0]]
		var tokens: int = part["tokens"]
		var color: Color = row[1]
		var key: String = row[2]
		var count: int = part.get("count", part.get("files", 0))
		if tokens > 0:
			var seg := ColorRect.new()
			seg.color = color
			seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			seg.size_flags_stretch_ratio = float(tokens)
			_bar.add_child(seg)
		var line := Label.new()
		line.text = AISidebarI18n.get_text(key, {"percent": "%.1f" % (100.0 * tokens / total), "tokens": tokens, "count": count})
		line.add_theme_color_override("font_color", color)
		_legend.add_child(line)
	var rules_d: Dictionary = m["rules"]
	if rules_d.get("truncated", false) == true:
		var warn := Label.new()
		warn.text = AISidebarI18n.get_text("custom_rules_truncated", {"max": AISidebarRulesRegistry.MAX_TOTAL_CHARS})
		warn.add_theme_color_override("font_color", Color(0.95, 0.7, 0.3))
		_legend.add_child(warn)

func _refresh_rules() -> void:
	for c: Node in _rules_list.get_children():
		c.queue_free()
	# Katman 0: eklentinin yerleşik kuralları (sistem istemi); global ve proje kuralları üstüne gelir.
	var m := AISidebarCustomizationBudget.measure()
	var sys: Dictionary = m["system"]
	var sys_row := HBoxContainer.new()
	var sys_badge := Label.new()
	sys_badge.text = AISidebarI18n.get_text("custom_scope_builtin")
	sys_badge.add_theme_font_size_override("font_size", 11)
	sys_row.add_child(sys_badge)
	var sys_lbl := Label.new()
	var sys_chars: int = sys["chars"]
	if sys.get("is_default", false) == true:
		sys_lbl.text = AISidebarI18n.get_text("custom_system_default", {"chars": sys_chars})
	else:
		sys_lbl.text = AISidebarI18n.get_text("custom_system_custom", {"chars": sys_chars})
	sys_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sys_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sys_row.add_child(sys_lbl)
	sys_row.add_child(_button("custom_edit_system", func() -> void: edit_system_prompt_requested.emit()))
	_rules_list.add_child(sys_row)
	var files := AISidebarRulesRegistry.discover()
	if files.is_empty():
		var none := Label.new()
		none.text = AISidebarI18n.get_text("custom_rules_none")
		_rules_list.add_child(none)
		return
	for f: Dictionary in files:
		var row := HBoxContainer.new()
		var badge := Label.new()
		if str(f["scope"]) == AISidebarRulesRegistry.SCOPE_GLOBAL:
			badge.text = AISidebarI18n.get_text("custom_scope_global")
		else:
			badge.text = AISidebarI18n.get_text("custom_scope_project")
		badge.add_theme_font_size_override("font_size", 11)
		row.add_child(badge)
		var path := Label.new()
		var chars: int = f["chars"]
		path.text = AISidebarI18n.get_text("custom_rule_file", {"path": str(f["path"]), "chars": chars})
		path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		path.clip_text = true
		row.add_child(path)
		var p := str(f["path"])
		row.add_child(_button("skills_open", func() -> void: OS.shell_open(ProjectSettings.globalize_path(p))))
		_rules_list.add_child(row)

func _open_rule_file(path: String) -> void:
	if path.is_empty():
		return
	var res := AISidebarRulesRegistry.ensure_file(path)
	if res.get("ok", false) == true:
		OS.shell_open(ProjectSettings.globalize_path(path))
	refresh()

func _on_add_rule() -> void:
	var scope := AISidebarRulesRegistry.SCOPE_GLOBAL if _rule_scope.selected == 1 else AISidebarRulesRegistry.SCOPE_PROJECT
	var res := AISidebarRulesRegistry.add_rule(_rule_edit.text, scope)
	if res.get("ok", false) == true:
		_rule_edit.clear()
		_status.text = AISidebarI18n.get_text("custom_rule_added", {"path": str(res["path"])})
	else:
		_status.text = AISidebarI18n.get_text("skills_error", {"error": str(res.get("error", ""))})
	refresh()
