@tool
extends AcceptDialog
class_name AISidebarSkillsPanel

## Başlıktaki Skills düğmesinin penceresi: yönetim görünümünü (AISidebarSkillsView) sarar.
## Ayarlar → Skill'ler sayfası aynı görünümü kullanır.

const AISidebarSkillsView = preload("res://addons/godot_sidebar_ai/ui/components/skills_view.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarSettingsUi = preload("res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

var view: AISidebarSkillsView

func _ready() -> void:
	title = AISidebarI18n.get_text("skills_title")
	theme = AISidebarSettingsUi.form_theme()
	min_size = Vector2i(Vector2(560, 460) * maxf(1.0, AISidebarTheme.ui_scale))
	ok_button_text = AISidebarI18n.get_text("skills_close")
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	view = AISidebarSkillsView.new()
	scroll.add_child(view)
	about_to_popup.connect(view.refresh)
