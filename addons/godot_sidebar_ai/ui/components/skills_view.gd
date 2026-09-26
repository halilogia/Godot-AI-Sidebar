@tool
extends VBoxContainer
class_name AISidebarSkillsView

## Skill yönetimi görünümü (Skills penceresi ve Ayarlar → Skill'ler aynı görünümü kullanır): bulunan skill'leri kaynağıyla listeler; aç / kapa (config.json'a kişisel tercih),
## SKILL.md'yi aç, kullanıcı / proje skill'ini sil, yeni skill iskeleti oluştur, başka bir yerdeki
## skill klasörünü içe aktar, kullanıcı skill klasörünü aç. Proje skill'leri depodan geldiği için
## kullanıcı açana kadar kapalıdır.

const AISidebarSkillRegistry = preload("res://addons/godot_sidebar_ai/core/skills/skill_registry.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

var _list: VBoxContainer
var _name_edit: LineEdit
var _scope_opt: OptionButton
var _status: Label
var _dir_dialog: FileDialog
var _confirm: ConfirmationDialog
var _pending_delete: Dictionary = {}

func _ready() -> void:
	var root := self
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)

	var hint := Label.new()
	hint.text = AISidebarI18n.get_text("skills_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var create_row := HBoxContainer.new()
	root.add_child(create_row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = AISidebarI18n.get_text("skills_new_placeholder")
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_row.add_child(_name_edit)
	_scope_opt = OptionButton.new()
	_scope_opt.add_item(AISidebarI18n.get_text("skills_scope_user"), 0)
	_scope_opt.add_item(AISidebarI18n.get_text("skills_scope_project"), 1)
	create_row.add_child(_scope_opt)
	create_row.add_child(_button("skills_new", _on_new))

	var action_row := HBoxContainer.new()
	root.add_child(action_row)
	action_row.add_child(_button("skills_import", _on_import))
	action_row.add_child(_button("skills_open_user_dir", _on_open_user_dir))
	action_row.add_child(_button("skills_refresh", refresh))

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	root.add_child(_status)

	_dir_dialog = FileDialog.new()
	_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dir_dialog.dir_selected.connect(_on_import_dir)
	add_child(_dir_dialog)

	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(_on_delete_confirmed)
	add_child(_confirm)


func _button(key: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = AISidebarI18n.get_text(key)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b

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
		var empty := Label.new()
		empty.text = AISidebarI18n.get_text("skills_empty")
		_list.add_child(empty)
		return
	for s: Dictionary in skills:
		_list.add_child(_skill_row(s, AISidebarSkillRegistry.is_enabled(s, prefs)))

func _skill_row(s: Dictionary, enabled: bool) -> Control:
	var box := VBoxContainer.new()
	var row := HBoxContainer.new()
	box.add_child(row)
	var name := str(s.get("name", ""))
	var toggle := CheckBox.new()
	toggle.text = name
	toggle.button_pressed = enabled
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.toggled.connect(func(on: bool) -> void: AISidebarSkillRegistry.set_enabled(name, on))
	row.add_child(toggle)
	var scope := Label.new()
	scope.text = _scope_text(str(s.get("scope", "")))
	scope.add_theme_font_size_override("font_size", 11)
	row.add_child(scope)
	var location := str(s.get("location", ""))
	row.add_child(_button("skills_open", func() -> void: OS.shell_open(ProjectSettings.globalize_path(location))))
	if str(s.get("scope", "")) != AISidebarSkillRegistry.SCOPE_BUILTIN:
		row.add_child(_button("skills_delete", func() -> void: _ask_delete(s)))
	var desc := Label.new()
	desc.text = str(s.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.modulate = Color(1, 1, 1, 0.75)
	box.add_child(desc)
	var warnings: Array = s.get("warnings", [])
	if warnings.size() > 0:
		var warn := Label.new()
		warn.text = AISidebarI18n.get_text("skills_warning", {"text": "; ".join(PackedStringArray(warnings))})
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.add_theme_font_size_override("font_size", 10)
		box.add_child(warn)
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
		_status.text = AISidebarI18n.get_text("skills_done")
	else:
		_status.text = AISidebarI18n.get_text("skills_error", {"error": str(res.get("error", ""))})
