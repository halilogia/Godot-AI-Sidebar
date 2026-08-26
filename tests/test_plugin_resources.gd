@tool
extends RefCounted

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	# Test 1: Load settings_dialog.tscn
	var settings_path = "res://addons/godot_sidebar_ai/ui/dialogs/settings_dialog.tscn"
	if ResourceLoader.exists(settings_path):
		var settings_packed = load(settings_path)
		if settings_packed is PackedScene:
			var inst = settings_packed.instantiate()
			if inst is AcceptDialog and inst.has_node("VBox/UrlContainer/BaseUrlEdit"):
				passed += 1
				inst.queue_free()
			else:
				failed += 1
				errors.append("settings_dialog.tscn beklenen düğümlere sahip değil.")
		else:
			failed += 1
			errors.append("settings_dialog.tscn PackedScene olarak yüklenemedi.")
	else:
		failed += 1
		errors.append("settings_dialog.tscn bulunamadı: " + settings_path)
		
	# Test 2: Load change_set_dialog.tscn
	var cs_path = "res://addons/godot_sidebar_ai/ui/dialogs/change_set_dialog.tscn"
	if ResourceLoader.exists(cs_path):
		var cs_packed = load(cs_path)
		if cs_packed is PackedScene:
			var cs_inst = cs_packed.instantiate()
			if cs_inst is ConfirmationDialog:
				passed += 1
				cs_inst.queue_free()
			else:
				failed += 1
				errors.append("change_set_dialog.tscn ConfirmationDialog değil.")
		else:
			failed += 1
			errors.append("change_set_dialog.tscn PackedScene olarak yüklenemedi.")
	else:
		failed += 1
		errors.append("change_set_dialog.tscn bulunamadı.")
		
	# Test 3: Instantiate chat_dock.tscn and verify SettingsDialog instance
	var dock_path = "res://addons/godot_sidebar_ai/ui/docks/chat_dock.tscn"
	if ResourceLoader.exists(dock_path):
		var dock_packed = load(dock_path)
		if dock_packed is PackedScene:
			var dock_inst = dock_packed.instantiate()
			if dock_inst is Control:
				var set_dlg = dock_inst.get_node_or_null("SettingsDialog")
				var cs_dlg = dock_inst.get_node_or_null("ChangeSetDialog")
				if set_dlg != null and cs_dlg != null and not (set_dlg.get_class() == "MissingNode"):
					passed += 1
				else:
					failed += 1
					errors.append("chat_dock içindeki SettingsDialog veya ChangeSetDialog MissingNode!")
				dock_inst.queue_free()
			else:
				failed += 1
				errors.append("chat_dock.tscn Control değil.")
		else:
			failed += 1
			errors.append("chat_dock.tscn yüklenemedi.")
	else:
		failed += 1
		errors.append("chat_dock.tscn bulunamadı.")
		
	return {"name": "PluginResourcesTests", "passed": passed, "failed": failed, "errors": errors}
