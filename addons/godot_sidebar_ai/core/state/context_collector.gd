@tool
extends RefCounted
class_name AISidebarContextCollector

## Bağlam Toplayıcı ve İlgililik Filtresi (Context Engine & Relevance Layer) (SRP).
## Editör durumundan sadece kullanıcı göreviyle ilgili olan bilgileri toplar ve kompakt bağlam üretir.

const AISidebarEditorStateSnapshot = preload("res://addons/godot_sidebar_ai/core/state/editor_state_snapshot.gd")

static func collect_grounding_context(user_prompt: String = "", recent_changes: Array = []) -> String:
	var snap = AISidebarEditorStateSnapshot.capture_snapshot()
	var lines: PackedStringArray = []
	
	lines.append("=== GODOT EDITÖR ZEMİN BİLGİSİ (EDITOR GROUNDING) ===")
	
	# 1. Aktif Sahne
	if snap.get("has_active_scene", false):
		lines.append("Aktif Sahne: " + snap.get("active_scene_name", "") + " (" + snap.get("active_scene_file", "") + ")")
	else:
		lines.append("Aktif Sahne: Açık sahne yok.")
		
	# 2. Seçili Düğümler
	var sel: Array = snap.get("selected_nodes", [])
	if sel.size() > 0:
		var sel_str: PackedStringArray = []
		for s in sel:
			sel_str.append(s.get("name", "") + " [" + s.get("type", "") + "] @ " + s.get("path", ""))
		lines.append("Seçili Düğümler: " + "; ".join(sel_str))
	else:
		lines.append("Seçili Düğüm: Yok.")
		
	# 3. Son Değişiklikler (Recent AI Changes)
	if recent_changes.size() > 0:
		lines.append("Son Yapılan Değişiklikler:")
		for ch in recent_changes.slice(-3):
			lines.append(" - " + str(ch))
			
	lines.append("======================================================")
	return "\n".join(lines)
