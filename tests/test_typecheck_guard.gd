@tool
extends RefCounted

## Typecheck guard mekanizması: parse probu iki yönde deterministik çalışır.
## (Wrapper fail-closed taraması typecheck.ps1 içindedir; kanıtı rapordadır.)

const TypecheckTool = preload("res://tools/typecheck.gd")
const WarningReport = preload("res://tools/warning_report.gd")

static func _probe_source(src: String) -> bool:
	var g = GDScript.new()
	g.set_source_code(src)
	return g.reload() == OK

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Bilinen-sağlam dosya probu geçer (temiz repo -> PASS yönü)
	if TypecheckTool.probe_parse("res://tests/test_type_parser.gd"):
		passed += 1
	else:
		failed += 1
		errors.append("T1 (probe passes on valid file) failed.")

	# 2. Bozuk kaynak probu kalır (kasıtlı syntax-error yönü; repo kirlenmez)
	var broken_src = "@tool\nextends RefCounted\n\nstatic func broken(:\n\tpass blot\n"
	if not _probe_source(broken_src):
		passed += 1
	else:
		failed += 1
		errors.append("T2 (probe fails on broken source) failed.")

	# 3. Mevcut olmayan dosya güvenli false (crash yok)
	if not TypecheckTool.probe_parse("res://tests/__missing_nope__.gd"):
		passed += 1
	else:
		failed += 1
		errors.append("T3 (probe false on missing file) failed.")

	# 4. Uyarı raporu ayrıştırıcısı: işaretten sonraki "treated as error" satırları o
	# dosya/türe sayılır; işaretsiz satır ve başka hata sayılmaz.
	var sample = "\n".join([
		"SCRIPT ERROR: Parse Error: Variable \"x\" has no static type. (Warning treated as error.)",
		WarningReport.MARK_FILE + "untyped_declaration res://addons/godot_sidebar_ai/a.gd",
		"SCRIPT ERROR: Parse Error: Variable \"x\" has no static type. (Warning treated as error.)",
		"   at: GDScript::reload (res://addons/godot_sidebar_ai/a.gd:2)",
		"SCRIPT ERROR: Parse Error: Parameter \"a\" has no static type. (Warning treated as error.)",
		WarningReport.MARK_FILE + "unsafe_cast res://addons/godot_sidebar_ai/a.gd",
		"SCRIPT ERROR: Parse Error: Expected parameter name.",
		WarningReport.MARK_FILE + "unsafe_cast res://addons/godot_sidebar_ai/sub/b.gd",
		"SCRIPT ERROR: Parse Error: Casting \"Variant\" to \"Node\" is unsafe. (Warning treated as error.)",
		WarningReport.MARK_DONE,
	])
	var parsed = WarningReport.parse_output(sample)
	if parsed == {"a.gd": {"untyped_declaration": 2}, "sub/b.gd": {"unsafe_cast": 1}}:
		passed += 1
	else:
		failed += 1
		errors.append("T4 (warning report parse) failed: " + str(parsed))

	# 5. Cırcır: artış (ve tabanda olmayan yeni dosyada > 0) başarısız; eşit / azalma geçer.
	var base = {"a.gd": {"untyped_declaration": 2, "unsafe_cast": 1}}
	var same = WarningReport.regressions({"a.gd": {"untyped_declaration": 2}}, base)
	var up = WarningReport.regressions({"a.gd": {"untyped_declaration": 3}}, base)
	var new_file = WarningReport.regressions({"n.gd": {"unsafe_cast": 1}}, base)
	if same.is_empty() and up == ["a.gd untyped_declaration: 3 > 2"] and new_file == ["n.gd unsafe_cast: 1 > 0"]:
		passed += 1
	else:
		failed += 1
		errors.append("T5 (warning ratchet) failed: same=%s up=%s new=%s" % [str(same), str(up), str(new_file)])

	return {"name": "TypecheckGuardTests", "passed": passed, "failed": failed, "errors": errors}
