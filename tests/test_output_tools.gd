@tool
extends RefCounted

## get_output: editör günlük dinleyicisi (arabellek, süzgeç, halka sınırı, maskeleme, gürültü atlama),
## oyun tarafı dinleyici (print / hata satırları) ve araç argümanlarının normalleştirilmesi.

const AISidebarEditorOutput = preload("res://addons/godot_sidebar_ai/core/runtime/editor_output.gd")
const AISidebarOutputTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/output_tools.gd")
const AISidebarRuntimeBridge = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_bridge.gd")

static func run() -> Dictionary:
	var checks: Array = []

	# O1 editör dinleyicisi: mesaj / hata / uyarı sınıflanır, gürültü atlanır
	var sink := AISidebarEditorOutput.Sink.new()
	sink._log_message("hello from editor\n", false)
	sink._log_message("[TIMING] 12:00 | NOISE", false)
	sink._log_message("", false)
	sink._log_error("f", "res://a.gd", 7, "", "Failed to create an autoload", false, Logger.ERROR_TYPE_ERROR, [])
	sink._log_error("f", "res://a.gd", 9, "", "unused variable", false, Logger.ERROR_TYPE_WARNING, [])
	sink._log_error("f", "gdscript://123.gd", 1, "", "compile mirror noise", false, Logger.ERROR_TYPE_SCRIPT, [])
	var all := sink.recent("all", 50, "")
	var errs := sink.recent("errors", 50, "")
	checks.append(["O1 kinds classified, noise skipped", all.size() == 3 and errs.size() == 2 and str((all[1] as Dictionary)["kind"]) == "error" and str((all[2] as Dictionary)["kind"]) == "warning" and str((errs[0] as Dictionary)["text"]).contains("res://a.gd:7")])

	# O2 süzgeç ve limit (en yeni sonda)
	var filtered := sink.recent("all", 50, "AUTOLOAD")
	var limited := sink.recent("all", 1, "")
	checks.append(["O2 contains filter and limit keep the newest", filtered.size() == 1 and limited.size() == 1 and str((limited[0] as Dictionary)["kind"]) == "warning"])

	# O3 halka: en çok MAX_LINES satır
	var big := AISidebarEditorOutput.Sink.new()
	for i in AISidebarEditorOutput.MAX_LINES + 25:
		big._log_message("line %d" % i, false)
	var kept := big.recent("all", 1000, "")
	checks.append(["O3 ring buffer capped", kept.size() == AISidebarEditorOutput.MAX_LINES and str((kept[0] as Dictionary)["text"]) == "line 25" and big.total == AISidebarEditorOutput.MAX_LINES + 25])

	# O4 sırlar maskelenir (anahtar biçimi, Bearer, anahtar=değer)
	var masked := AISidebarEditorOutput.mask_secrets('key sk-FAKEFAKE0123456789-abcdef and Authorization: Bearer abcdef123456789 and api_key="supersecret99"')
	checks.append(["O4 secrets masked", not masked.contains("FAKEFAKE0") and not masked.contains("abcdef123456789") and not masked.contains("supersecret99") and masked.contains("***")])
	var secret_sink := AISidebarEditorOutput.Sink.new()
	secret_sink._log_message("token=abcdefghij1234", false)
	checks.append(["O4b masked before it is stored", not str((secret_sink.recent("all", 5, "")[0] as Dictionary)["text"]).contains("abcdefghij1234")])

	# O5 oyun tarafı dinleyici: print + hata + uyarı; hata sayacı yalnız hatayı sayar
	var game := AISidebarRuntimeBridge.ErrorSink.new()
	game._log_message("player spawned at (10, 20)", false)
	game._log_error("_ready", "res://p.gd", 12, "", "Invalid call. Nonexistent function 'foo' in base 'Nil'.", false, Logger.ERROR_TYPE_SCRIPT, [])
	game._log_error("_ready", "res://p.gd", 13, "", "deprecated thing", false, Logger.ERROR_TYPE_WARNING, [])
	var game_all := game.recent_output("all", 20, "")
	var game_err := game.recent_output("errors", 20, "")
	var game_find := game.recent_output("all", 20, "spawned")
	checks.append(["O5 game sink keeps prints, errors and warnings; counter counts only errors", game_all.size() == 3 and game_err.size() == 2 and game_find.size() == 1 and game.total == 1 and game.since(0).size() == 1])

	# O6 araç argümanları
	var n1 := AISidebarOutputTools.normalize_args({"source": "nope", "level": "x", "limit": 9999})
	var n2 := AISidebarOutputTools.normalize_args({"source": "game", "level": "errors", "limit": "5", "contains": "foo"})
	checks.append(["O6 args normalized", n1["source"] == "both" and n1["level"] == "all" and n1["limit"] == AISidebarOutputTools.MAX_LIMIT and n2["source"] == "game" and n2["level"] == "errors" and n2["limit"] == 5 and n2["contains"] == "foo"])

	# O7 satır biçimi
	var fmt := AISidebarOutputTools.format_lines([{"kind": "error", "text": "boom"}, {"kind": "message", "text": "hi"}, {"kind": "warning", "text": "w"}])
	checks.append(["O7 line format", fmt == ["[error] boom", "[log] hi", "[warning] w"]])

	var passed := 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed")
	return {"name": "OutputToolsTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}
