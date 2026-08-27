@tool
extends RefCounted
class_name AISidebarEditorStateSnapshot

## Editör Anlık Durum ve Seçim Yakalayıcısı (Editor Grounding Context) (SRP).
## Aktif sahne, seçili düğüm, açık script ve proje bilgilerini güvenle toplar.

static func capture_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"project_name": ProjectSettings.get_setting("application/config/name", "Godot Project"),
		"has_active_scene": false,
		"active_scene_name": "",
		"active_scene_file": "",
		"active_scene_root_type": "",
		"selected_nodes": [],
		"primary_selected_node": {},
		"active_script_path": "",
		"recent_errors": []
	}
	
	if not Engine.is_editor_hint():
		return snapshot
		
	if ClassDB.class_exists("EditorInterface"):
		# 1. Aktif Sahne
		if EditorInterface.has_method("get_edited_scene_root"):
			var root = EditorInterface.get_edited_scene_root()
			if root:
				snapshot["has_active_scene"] = true
				snapshot["active_scene_name"] = root.name
				snapshot["active_scene_file"] = root.scene_file_path
				snapshot["active_scene_root_type"] = root.get_class()
				
		# 2. Seçili Düğümler (Selection Awareness)
		if EditorInterface.has_method("get_selection"):
			var selection = EditorInterface.get_selection()
			if selection:
				var sel_nodes = selection.get_selected_nodes()
				var sel_array: Array = []
				for node in sel_nodes:
					sel_array.append({
						"name": node.name,
						"path": str(node.get_path()),
						"type": node.get_class()
					})
				snapshot["selected_nodes"] = sel_array
				if sel_array.size() > 0:
					snapshot["primary_selected_node"] = sel_array[0]
					
		# 3. Açık Script (Active Script Awareness)
		if EditorInterface.has_method("get_script_editor"):
			var script_editor = EditorInterface.get_script_editor()
			if script_editor and script_editor.has_method("get_current_script"):
				var curr_script = script_editor.get_current_script()
				if curr_script:
					snapshot["active_script_path"] = curr_script.resource_path
					
	return snapshot

## Ajan için kompakt ve seçim odaklı zemin metni üretir
static func get_grounding_prompt_text() -> String:
	var snap = capture_snapshot()
	var lines: PackedStringArray = []
	
	lines.append("=== GODOT EDITÖR ZEMİN BİLGİSİ (EDITOR GROUNDING) ===")
	lines.append("Proje: " + str(snap.get("project_name", "Godot Project")))
	
	if snap.get("has_active_scene", false):
		lines.append("Aktif Sahne: " + snap.get("active_scene_name", "") + " [" + snap.get("active_scene_root_type", "Node") + "] (" + snap.get("active_scene_file", "") + ")")
	else:
		lines.append("Aktif Sahne: Açık sahne yok.")
		
	var sel: Array = snap.get("selected_nodes", [])
	if sel.size() > 0:
		var sel_str: PackedStringArray = []
		for s in sel:
			sel_str.append(s.get("name", "") + " [" + s.get("type", "") + "] @ " + s.get("path", ""))
		lines.append("Seçili Düğümler: " + "; ".join(sel_str))
		var prim = snap.get("primary_selected_node", {})
		if not prim.is_empty():
			lines.append("👉 BİRİNCİL SEÇİLİ DÜĞÜM (Kullanıcı 'bu/bunun' dediğinde geçerli olan): " + prim.get("name", "") + " [" + prim.get("type", "") + "]")
	else:
		lines.append("Seçili Düğüm: Yok.")
		
	var active_scr = snap.get("active_script_path", "")
	if not active_scr.is_empty():
		lines.append("Açık Script: " + active_scr)
		
	lines.append("=== NETLEŞTİRME KURALI (CLARIFICATION POLICY) ===")
	lines.append("- Yalnızca sonucu KÖKTEN değiştirecek ve aktif editör bağlamından çıkarılamayan durumlarda 'ask_user' aracını kullanarak kullanıcıya soru sorun (Örn: 'Sahne oluştur ve slime yap' dendiğinde 2D mi 3D mi olduğu hem promptta hem açık sahnede belirsizse).")
	lines.append("- Belirsizlik sonucu önemli ölçüde değiştirmiyorsa makul varsayım yapıp doğrudan işe başlayın.")
	lines.append("- Güvenli ve açık bir varsayım varsa veya aktif sahnede zaten Node2D/Node3D varsa soru sormayın, bağlamı takip edin.")
	lines.append("- Önemsiz detaylar için (hız, renk, boyut vb.) KESİNLİKLE soru sormayın, varsayılan mantıklı değerleri uygulayın.")
	lines.append("======================================================")
	return "\n".join(lines)
