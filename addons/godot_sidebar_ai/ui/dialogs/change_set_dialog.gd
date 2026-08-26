@tool
extends ConfirmationDialog
class_name AISidebarChangeSetDialog

## Görsel Değişiklik ve Diff Onay Penceresi (ChangeSet Diff & Approval Dialog) (SRP).
## Viewport kısıtları (%85x%80) ve dahili kaydırma (Scroll) ile ideal boyutta açılır.

const AISidebarChangeSet = preload("res://addons/godot_sidebar_ai/core/types/change_set.gd")

signal action_approved()
signal action_rejected()

@onready var header_label: RichTextLabel = $Margin/VBox/HeaderLabel
@onready var summary_label: RichTextLabel = $Margin/VBox/SummaryLabel
@onready var diff_rich_text: RichTextLabel = $Margin/VBox/DiffScroll/DiffRichText

var current_change_set: AISidebarChangeSet = null

func _ready() -> void:
	title = "AI Değişiklik Onayı & Diff Görünümü"
	ok_button_text = "✓ Uygula (Approve)"
	cancel_button_text = "✕ Reddet (Reject)"
	unresizable = false
	
	confirmed.connect(_on_confirmed)
	canceled.connect(_on_canceled)

func show_change_set(tool_name: String, args: Dictionary, cs: AISidebarChangeSet) -> void:
	current_change_set = cs
	
	if not header_label or not summary_label or not diff_rich_text:
		return
		
	# 1. Viewport Kısıtları Hesaplama (max %85 genişlik x %80 yükseklik)
	var vp_size = Vector2(1280, 720)
	if get_viewport():
		vp_size = get_viewport().get_visible_rect().size
	elif DisplayServer.window_get_size().x > 0:
		vp_size = Vector2(DisplayServer.window_get_size())
		
	var max_w = maxi(580, int(vp_size.x * 0.85))
	var max_h = maxi(420, int(vp_size.y * 0.80))
	var min_w = 520
	var min_h = 360
	
	var target_w = clampi(720, min_w, max_w)
	var target_h = clampi(500, min_h, max_h)
	
	min_size = Vector2i(min_w, min_h)
	max_size = Vector2i(max_w, max_h)
	size = Vector2i(target_w, target_h)
	
	# 2. İçerik ve Diff Doldurma
	if cs:
		var deltas = cs.get_file_deltas()
		header_label.text = "[b][color=#88c0d0]Changes (" + str(deltas.size()) + " files)[/color][/b]"
		
		var sum_lines: PackedStringArray = []
		for d in deltas:
			sum_lines.append("  • [b]" + d["file_name"] + "[/b] [color=#a3be8c]+" + str(d["added"]) + "[/color] [color=#bf616a]-" + str(d["removed"]) + "[/color]")
		summary_label.text = "\n".join(sum_lines)
		
		diff_rich_text.text = cs.get_bbcode_diff()
	else:
		header_label.text = "[b][color=#d08770]İşlem Onayı: " + tool_name + "[/color][/b]"
		summary_label.text = "Parametreler: " + JSON.stringify(args)
		diff_rich_text.text = "[color=#9399b2]Bu işlem sahne veya dosya üzerinde kalıcı değişiklik yapacaktır.[/color]"
		
	popup_centered(Vector2i(target_w, target_h))

func _on_confirmed() -> void:
	action_approved.emit()

func _on_canceled() -> void:
	action_rejected.emit()
