@tool
extends RefCounted

## Typecheck guard mekanizması: parse probu iki yönde deterministik çalışır.
## (Wrapper fail-closed taraması typecheck.ps1 içindedir; kanıtı rapordadır.)

const TypecheckTool = preload("res://tools/typecheck.gd")

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

	return {"name": "TypecheckGuardTests", "passed": passed, "failed": failed, "errors": errors}
