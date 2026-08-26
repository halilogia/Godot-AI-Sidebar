@tool
extends RefCounted
class_name AISidebarEditorStateSnapshot

## Editör Anlık Durum Yakalayıcısı (Editor Grounding Context) (SRP).
## İlk kullanıcı isteğinde veya durum değişiminde aktif sahne, seçili düğümler ve hataları toplar.

static func capture_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"has_active_scene": false,
		"active_scene_name": "",
		"active_scene_file": "",
		"selected_nodes": [],
		"recent_errors": []
	}
	
	var root = EditorInterface.get_edited_scene_root()
	if root:
		snapshot["has_active_scene"] = true
		snapshot["active_scene_name"] = root.name
		snapshot["active_scene_file"] = root.scene_file_path
		
	var selection = EditorInterface.get_selection()
	if selection:
		var sel_array: Array = []
		for node in selection.get_selected_nodes():
			sel_array.append({
				"name": node.name,
				"path": str(node.get_path()),
				"type": node.get_class()
			})
		snapshot["selected_nodes"] = sel_array
		
	return snapshot

## Ajan için kompakt zemin (grounding) metni üretir (~3-5 satır, minimum token harcar)
static func get_grounding_prompt_text() -> String:
	var snap = capture_snapshot()
	var lines: PackedStringArray = []
	
	if snap["has_active_scene"]:
		lines.append("[Editor Context] Aktif Sahne: " + snap["active_scene_name"] + " (" + snap["active_scene_file"] + ")")
	else:
		lines.append("[Editor Context] Açık sahne yok.")
		
	var sel: Array = snap["selected_nodes"]
	if sel.size() > 0:
		var sel_str: PackedStringArray = []
		for s in sel:
			sel_str.append(s["name"] + " (" + s["type"] + ")")
		lines.append("[Editor Context] Seçili Düğümler: " + ", ".join(sel_str))
	else:
		lines.append("[Editor Context] Seçili düğüm yok.")
		
	return "\n".join(lines)
