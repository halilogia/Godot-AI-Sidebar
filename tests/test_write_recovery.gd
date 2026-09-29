@tool
extends RefCounted

## Yazma kurtarma: yalnız sözdizimi hatası yazımı engeller; derlenmeyen dosya diske yazılıp raporlanır
## (WRITTEN_WITH_ERRORS), batch dosya dosya uygulanır, reddedilen dosyayı yamamaya kalkan ajana nedeni
## söylenir, file_info / search_code diskin gerçek durumunu gösterir, hatalı dosya kalmışken görev bitmez.
## (Benchmark: tek bozuk dosya bütün batch'i siliyor, model yazılmamış dosyayı yamamaya çalışıyordu.)

const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")
const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")
const AISidebarCompletionPolicy = preload("res://addons/godot_sidebar_ai/core/agent/completion_policy.gd")

const GOOD := "res://tests/temp_w_good.gd"
const BAD := "res://tests/temp_w_bad.gd"
const DIRTY := "res://tests/temp_w_dirty.gd"
const SYNTAX_SRC := "extends Node\nfunc broken(:\n\tpass\n"
const DIRTY_SRC := "extends Node\nfunc f() -> void:\n\tvar x = TotallyMissingThing.new()\n"
const GOOD_SRC := "extends Node\nfunc good_marker_w() -> void:\n\tpass\n"

static func _clean() -> void:
	for p: String in [GOOD, BAD, DIRTY]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	AISidebarScriptTools.reset_write_state()

static func _data(r: Dictionary) -> Dictionary:
	var d: Variant = r.get("data", null)
	return d if d is Dictionary else {}

static func run() -> Dictionary:
	var checks: Array = []
	_clean()

	# W1 sınıflandırma
	var syn := AISidebarVerificationPipeline.validate_source(SYNTAX_SRC, BAD)
	var dirty := AISidebarVerificationPipeline.validate_source(DIRTY_SRC, DIRTY)
	checks.append(["W1 syntax blocks, undeclared identifier does not", AISidebarVerificationPipeline.blocks_write(syn) and not dirty.get("success", true) and not AISidebarVerificationPipeline.blocks_write(dirty)])

	# W2 batch dosya dosya: temiz + sözdizimi hatalı + derlenmeyen
	var r2 := AISidebarScriptTools.execute("write_files", {"files": [
		{"file_path": GOOD, "content": GOOD_SRC},
		{"file_path": BAD, "content": SYNTAX_SRC},
		{"file_path": DIRTY, "content": DIRTY_SRC},
	]})
	var d2 := _data(r2)
	checks.append(["W2 partial apply (%s)" % str(d2.get("message", r2.get("error"))), r2.get("success") == true and d2.get("operation_status") == "PARTIAL" and FileAccess.file_exists(GOOD) and FileAccess.file_exists(DIRTY) and not FileAccess.file_exists(BAD) and (d2.get("rejected_files", {}) as Dictionary).has(BAD) and (d2.get("files_with_errors", {}) as Dictionary).has(DIRTY)])

	# W3 reddedilen dosyayı yamamak: nedeni söylenir
	var r3 := AISidebarScriptTools.execute("replace_file_content", {"file_path": BAD, "target_code": "pass", "replacement_code": "return"})
	var e3: Dictionary = r3.get("error", {}) if r3.get("error") is Dictionary else {}
	checks.append(["W3 patch of rejected file says it was never written", e3.get("code") == "FILE_NOT_WRITTEN" and _data(r3).get("disk_state") == "MISSING"])

	# W4 file_info
	var i4 := _data(AISidebarScriptTools.execute("file_info", {"file_path": BAD}))
	var i4b := _data(AISidebarScriptTools.execute("file_info", {"file_path": GOOD}))
	checks.append(["W4 file_info exists/previous_write", i4.get("exists") == false and i4.has("previous_write") and i4b.get("exists") == true and int(i4b.get("line_count", 0)) > 0])

	# W5 / W6 search_code
	var s5 := _data(AISidebarScriptTools.execute("search_code", {"query": "good_marker_w", "path": "res://tests"}))
	var m5: Array = s5.get("matches", [])
	checks.append(["W5 search_code finds file:line", m5.size() >= 1 and (m5[0] as Dictionary).get("file_path") == GOOD and int((m5[0] as Dictionary).get("line", 0)) == 2])
	var s6 := _data(AISidebarScriptTools.execute("search_code", {"query": "zz_no_such" + "_text_zz", "path": "res://tests"}))
	checks.append(["W6 empty search does not claim missing file", (s6.get("matches", []) as Array).is_empty() and str(s6.get("message", "")).contains("does NOT")])

	# W6b find_files: kalıp ad ya da yola uyar; bulunamayınca varlık hakkında yanıltmaz
	var ff := _data(AISidebarScriptTools.execute("find_files", {"pattern": "temp_w_*.gd", "path": "res://tests"}))
	var ff_plain := _data(AISidebarScriptTools.execute("find_files", {"pattern": "TEMP_W_GOOD", "path": "res://tests"}))
	var ff_none := _data(AISidebarScriptTools.execute("find_files", {"pattern": "zz_nothing_here_zz*", "path": "res://tests"}))
	checks.append(["W6b find_files wildcard / plain / none", (ff.get("files", []) as Array).has(GOOD) and (ff_plain.get("files", []) as Array) == [GOOD] and int(ff_none.get("count", -1)) == 0 and str(ff_none.get("message", "")).contains("file_info") and AISidebarScriptTools.path_matches("res://scenes/main/level_1.tscn", "scenes/*.tscn")])

	# W6c hata bağlamı ve hedef-bulunamadı ipucu
	var src := "extends Node
func a():
	pass
func broken(:
	pass
func z():
	pass
"
	var vr := AISidebarVerificationPipeline.validate_source(src, "res://tests/temp_ctx.gd")
	var ctx := AISidebarScriptTools.error_context(src, vr)
	var old_file := "extends Node

func _ready() -> void:
	var x := 1
	print(x)
"
	var tnf: Dictionary = AISidebarScriptTools.target_not_found_error("res://a.gd", old_file, "func _ready() -> void:
    var x := 2
")
	var tnf_none: Dictionary = AISidebarScriptTools.target_not_found_error("res://a.gd", old_file, "func nothing_like_it():
	pass
")
	var tnf_msg: String = str((tnf.get("error", {}) as Dictionary).get("message", ""))
	var none_msg: String = str((tnf_none.get("error", {}) as Dictionary).get("message", ""))
	checks.append(["W6c error context + target hints", ctx.contains(">4| func broken(:") and ctx.contains(" 3| 	pass") and tnf_msg.contains("line 3") and tnf_msg.contains("3| func _ready()") and tnf_msg.contains("tabs") and none_msg.contains("read_script")])

	# W7 açık sorunlar görevi bitirmez; düzeltilince kayıt temizlenir
	var gate := AISidebarCompletionPolicy.evaluate({"write_problems": "Files on disk that do not compile: x"})
	AISidebarScriptTools.execute("create_or_update_script", {"file_path": DIRTY, "content": GOOD_SRC.replace("good_marker_w", "fixed")})
	AISidebarScriptTools.execute("create_or_update_script", {"file_path": BAD, "content": GOOD_SRC.replace("good_marker_w", "fixed2")})
	AISidebarScriptTools.refresh_write_state()
	checks.append(["W7 gate incomplete; fixes clear the registry", gate.get("verdict") == "incomplete" and AISidebarScriptTools.files_with_errors.is_empty() and AISidebarScriptTools.rejected_writes.is_empty()])

	# W8 hepsi sözdizimi hatalı: hiçbir şey yazılmaz, açıkça söylenir
	_clean()
	var r8 := AISidebarScriptTools.execute("write_files", {"files": [{"file_path": BAD, "content": SYNTAX_SRC}]})
	var e8: Dictionary = r8.get("error", {}) if r8.get("error") is Dictionary else {}
	checks.append(["W8 all rejected -> NO file written", e8.get("code") == "SCRIPT_SYNTAX_ERROR" and str(e8.get("message", "")).contains("NO file") and not FileAccess.file_exists(BAD)])

	# W9 tek dosya derlenmiyorsa yazılır, WRITTEN_WITH_ERRORS
	var r9 := AISidebarScriptTools.execute("create_or_update_script", {"file_path": DIRTY, "content": DIRTY_SRC})
	var d9 := _data(r9)
	checks.append(["W9 single dirty write lands with FAILED verification", r9.get("success") == true and FileAccess.file_exists(DIRTY) and d9.get("verification_status") == "FAILED" and str(d9.get("message", "")).begins_with("WRITTEN_WITH_ERRORS")])

	_clean()
	var passed := 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed")
	return {"name": "WriteRecoveryTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}
