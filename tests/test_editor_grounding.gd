@tool
extends RefCounted

const AISidebarEditorStateSnapshot = preload("res://addons/godot_sidebar_ai/core/state/editor_state_snapshot.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Snapshot generation
	var snap = AISidebarEditorStateSnapshot.capture_snapshot()
	if snap.has("project_name") and snap.has("selected_nodes") and snap.has("primary_selected_node"):
		passed += 1
	else:
		failed += 1
		errors.append("Snapshot eksik alanlar içeriyor: " + str(snap))
		
	# Test 2: Grounding prompt format
	var text = AISidebarEditorStateSnapshot.get_grounding_prompt_text()
	if "=== GODOT EDITÖR ZEMİN BİLGİSİ (EDITOR GROUNDING) ===" in text:
		passed += 1
	else:
		failed += 1
		errors.append("Zeminleme başlığı bulunamadı: " + text)
		
	return {"name": "EditorGroundingTests", "passed": passed, "failed": failed, "errors": errors}
