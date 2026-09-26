@tool
extends AcceptDialog
class_name AISidebarSkillsPanel

## Başlıktaki Skills düğmesinin penceresi: yönetim görünümünü (AISidebarSkillsView) sarar.
## Ayarlar → Skill'ler sayfası aynı görünümü kullanır.

const AISidebarSkillsView = preload("res://addons/godot_sidebar_ai/ui/components/skills_view.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

var view: AISidebarSkillsView

func _ready() -> void:
	title = AISidebarI18n.get_text("skills_title")
	min_size = Vector2i(560, 460)
	ok_button_text = AISidebarI18n.get_text("skills_close")
	view = AISidebarSkillsView.new()
	add_child(view)
	about_to_popup.connect(view.refresh)
