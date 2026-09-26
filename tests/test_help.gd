@tool
extends RefCounted

## Kullanım rehberi güncel kalır: her slash komutunun iki dilde açıklaması vardır, Yardım penceresi her
## komutu listeler (komut kaydından üretilir) ve kılavuz bağlantısının gösterdiği dosyalar depoda vardır.

const AISidebarSlashCommandManager = preload("res://addons/godot_sidebar_ai/core/commands/slash_command_manager.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarHelpDialog = preload("res://addons/godot_sidebar_ai/ui/dialogs/help_dialog.gd")

const GUIDES: Array[String] = ["res://docs/USER_GUIDE.md", "res://docs/USER_GUIDE.en.md"]

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []
	var cmds: Dictionary = AISidebarSlashCommandManager.get_commands()

	# T1 Her komutun iki dilde açıklaması ve kullanım satırı var.
	var missing: Array[String] = []
	for lang: String in ["tr", "en"]:
		var keys: Array = AISidebarI18n.get_keys(lang)
		for n: Variant in cmds.keys():
			if not keys.has("cmd_desc_" + str(n)) or not keys.has("cmd_usage_" + str(n)):
				missing.append(lang + ":" + str(n))
	if missing.is_empty() and cmds.size() > 10:
		passed += 1
	else:
		failed += 1
		errors.append("T1 commands without cmd_desc_<name> / cmd_usage_<name> keys: " + str(missing))

	# T2 Yardım penceresi her komutun kullanımını listeler.
	var dlg := AISidebarHelpDialog.new()
	dlg.call("_build")
	var texts := dlg.collect_texts()
	var not_listed: Array[String] = []
	for n: Variant in cmds.keys():
		if not texts.has("/" + str(n)):
			not_listed.append(str(n))
	dlg.free()
	if not_listed.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T2 help dialog does not list: " + str(not_listed))

	# T3 Kılavuz dosyaları var ve her komutu anıyor (kılavuz komut eklenince güncellenir).
	var guide_gaps: Array[String] = []
	for g: String in GUIDES:
		if not FileAccess.file_exists(g):
			guide_gaps.append(g + " missing")
			continue
		var body := FileAccess.get_file_as_string(g)
		for n: Variant in cmds.keys():
			if not body.contains("/" + str(n)):
				guide_gaps.append(g.get_file() + " lacks /" + str(n))
	if guide_gaps.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T3 user guide: " + str(guide_gaps))

	return {"name": "HelpTests", "passed": passed, "failed": failed, "errors": errors}
