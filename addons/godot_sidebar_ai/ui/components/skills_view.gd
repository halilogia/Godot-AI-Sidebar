@tool
extends VBoxContainer
class_name AISidebarSkillsView

## Skill yönetimi görünümü (Skills penceresi ve Ayarlar → Skill'ler aynı görünümü kullanır): bulunan skill'leri kaynağıyla listeler; aç / kapa (config.json'a kişisel tercih),
## SKILL.md'yi aç, kullanıcı / proje skill'ini sil, yeni skill iskeleti oluştur, başka bir yerdeki
## skill klasörünü içe aktar, kullanıcı skill klasörünü aç. Proje skill'leri depodan geldiği için
## kullanıcı açana kadar kapalıdır.

const AISidebarSkillRegistry = preload("res://addons/godot_sidebar_ai/core/skills/skill_registry.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarSettingsUi = preload("res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd")

var _list: VBoxContainer
var _name_edit: LineEdit
var _scope_opt: OptionButton
var _status: Label
var _dir_dialog: FileDialog
var _confirm: ConfirmationDialog
var _pending_delete: Dictionary = {}

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_MD))

	var list_card := AISidebarSettingsUi.card(self, AISidebarI18n.get_text("custom_skills_title"), AISidebarI18n.get_text("skills_hint"))
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_SM))
	list_card.add_child(_list)

	var create_card := AISidebarSettingsUi.card(self, AISidebarI18n.get_text("skills_manage_title"))
	var create_row := AISidebarSettingsUi.row(create_card)
	_name_edit = AISidebarSettingsUi.line_edit(AISidebarI18n.get_text("skills_new_placeholder"))
	create_row.add_child(_name_edit)
	_scope_opt = AISidebarSettingsUi.option_button()
	_scope_opt.custom_minimum_size = Vector2(float(AISidebarSettingsUi.base_size) * 7.0, 0)
	_scope_opt.add_item(AISidebarI18n.get_text("skills_scope_user"), 0)
	_scope_opt.add_item(AISidebarI18n.get_text("skills_scope_project"), 1)
	create_row.add_child(_scope_opt)
	create_row.add_child(AISidebarSettingsUi.primary_button(AISidebarI18n.get_text("skills_new"), _on_new))
	var action_row := AISidebarSettingsUi.row(create_card)
	action_row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("skills_import"), _on_import))
	action_row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("skills_open_user_dir"), _on_open_user_dir))
	action_row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("skills_refresh"), refresh))
	_status = AISidebarSettingsUi.status_label()
	create_card.add_child(_status)

	_dir_dialog = FileDialog.new()
	_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dir_dialog.dir_selected.connect(_on_import_dir)
	add_child(_dir_dialog)

	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(_on_delete_confirmed)
	add_child(_confirm)

func _scope_text(scope: String) -> String:
	match scope:
		AISidebarSkillRegistry.SCOPE_PROJECT:
			return AISidebarI18n.get_text("skills_scope_project")
		AISidebarSkillRegistry.SCOPE_BUILTIN:
			return AISidebarI18n.get_text("skills_scope_builtin")
	return AISidebarI18n.get_text("skills_scope_user")

func _selected_scope() -> String:
	return AISidebarSkillRegistry.SCOPE_PROJECT if _scope_opt.selected == 1 else AISidebarSkillRegistry.SCOPE_USER

func refresh() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	var skills := AISidebarSkillRegistry.discover()
	var prefs := AISidebarSkillRegistry.load_prefs()
	if skills.is_empty():
		_list.add_child(AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("skills_empty")))
		return
	for s: Dictionary in skills:
		_list.add_child(_skill_row(s, AISidebarSkillRegistry.is_enabled(s, prefs)))

func _scope_color(scope: String) -> Color:
	match scope:
		AISidebarSkillRegistry.SCOPE_PROJECT:
			return AISidebarTheme.COLOR_LAYER_RULES
		AISidebarSkillRegistry.SCOPE_BUILTIN:
			return AISidebarTheme.COLOR_LAYER_SYSTEM
	return AISidebarTheme.COLOR_LAYER_TOOLS

func _skill_row(s: Dictionary, enabled: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", AISidebarTheme.px(AISidebarTheme.SPACE_XXS))
	var row := AISidebarSettingsUi.row(box)
	var name := str(s.get("name", ""))
	var toggle := CheckBox.new()
	toggle.text = name
	toggle.button_pressed = enabled
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.toggled.connect(func(on: bool) -> void: AISidebarSkillRegistry.set_enabled(name, on))
	row.add_child(toggle)
	var scope := str(s.get("scope", ""))
	row.add_child(AISidebarSettingsUi.badge(_scope_text(scope), _scope_color(scope)))
	var location := str(s.get("location", ""))
	row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("skills_open"), func() -> void: OS.shell_open(ProjectSettings.globalize_path(location))))
	if scope != AISidebarSkillRegistry.SCOPE_BUILTIN:
		row.add_child(AISidebarSettingsUi.button(AISidebarI18n.get_text("skills_delete"), func() -> void: _ask_delete(s)))
	var desc := AISidebarSettingsUi.hint_label(str(s.get("description", "")))
	box.add_child(desc)
	var warnings: Array = s.get("warnings", [])
	if warnings.size() > 0:
		var warn := AISidebarSettingsUi.hint_label(AISidebarI18n.get_text("skills_warning", {"text": "; ".join(PackedStringArray(warnings))}))
		warn.add_theme_color_override("font_color", AISidebarTheme.COLOR_WARNING)
		box.add_child(warn)
	box.add_child(HSeparator.new())
	return box

func _on_new() -> void:
	var res := AISidebarSkillRegistry.create_skill(_name_edit.text.strip_edges(), _selected_scope())
	_report(res)
	if res.get("ok", false) == true:
		_name_edit.clear()
		OS.shell_open(ProjectSettings.globalize_path(str(res["location"])))
		refresh()

func _on_import() -> void:
	_dir_dialog.popup_centered_ratio(0.6)

func _on_import_dir(dir: String) -> void:
	var res := AISidebarSkillRegistry.import_skill(dir, _selected_scope())
	_report(res)
	refresh()

func _on_open_user_dir() -> void:
	var dir := AISidebarSkillRegistry.user_skills_dir()
	if dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	OS.shell_open(dir)

func _ask_delete(s: Dictionary) -> void:
	_pending_delete = s
	_confirm.dialog_text = AISidebarI18n.get_text("skills_delete_confirm", {"name": str(s.get("name", "")), "path": str(s.get("dir", ""))})
	_confirm.popup_centered()

func _on_delete_confirmed() -> void:
	_report(AISidebarSkillRegistry.delete_skill(_pending_delete))
	_pending_delete = {}
	refresh()

func _report(res: Dictionary) -> void:
	if res.get("ok", false) == true:
		AISidebarSettingsUi.set_status(_status, AISidebarI18n.get_text("skills_done"))
	else:
		AISidebarSettingsUi.set_status(_status, AISidebarI18n.get_text("skills_error", {"error": str(res.get("error", ""))}), true)
