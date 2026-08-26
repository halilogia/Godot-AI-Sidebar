@tool
extends ConfirmationDialog
class_name AISidebarChangeSetDialog

## Görsel Değişiklik ve Diff Onay Penceresi (ChangeSet Diff & Approval Dialog) (SRP).
## Kullanıcıya onay bekleyen kod ve sahne değişikliklerinin diff görünümünü sunar.

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")

signal action_approved()
signal action_rejected()

@onready var summary_label: Label = $VBox/SummaryLabel
@onready var diff_text_edit: TextEdit = $VBox/DiffTextEdit

var current_change_set: AISidebarChangeSet = null

func _ready() -> void:
	title = "AI Değişiklik Onayı (ChangeSet Approval)"
	ok_button_text = "✓ Uygula (Approve)"
	cancel_button_text = "✕ Reddet (Reject)"
	
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)

func show_change_set(tool_name: String, args: Dictionary, cs: AISidebarChangeSet) -> void:
	current_change_set = cs
	
	if not summary_label or not diff_text_edit:
		return
		
	if cs:
		summary_label.text = cs.get_summary()
		diff_text_edit.text = cs.get_diff_text()
	else:
		summary_label.text = "İşlem: " + tool_name + "\nParametreler: " + JSON.stringify(args)
		diff_text_edit.text = "Bu işlem bir sahne veya dosya üzerinde kalıcı değişiklik yapacaktır.\nDevam etmek istiyor musunuz?"
		
	popup_centered(Vector2i(650, 480))

func _on_confirmed() -> void:
	action_approved.emit()

func _on_canceled() -> void:
	action_rejected.emit()
