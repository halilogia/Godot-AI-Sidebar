@tool
extends RefCounted

## Satır bütçesi (Refactor Faz 4): eklentideki bir .gd dosyası WARN_LIMIT'i aşarsa
## uyarı basılır, FAIL_LIMIT'i aşarsa test kırmızıya döner. Bilinçli istisnalar
## EXCEPTIONS'a gerekçesiyle yazılır (tavan satır sayısıyla; tavan aşılırsa yine kırmızı).
## Satır sayısı tek başına bölme sebebi değildir; aşım bir karar notu gerektirir
## (bkz. docs/REFACTOR_PLAN.md Faz 3 karar tablosu).

const ROOT = "res://addons/godot_sidebar_ai"
const WARN_LIMIT = 600
const FAIL_LIMIT = 900

## "yol (ROOT'a göre)": {"max": tavan, "reason": gerekçe}
const EXCEPTIONS: Dictionary = {}

static func _collect(path: String, out: Array) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(path.path_join(f))
	for d in dir.get_directories():
		_collect(path.path_join(d), out)

## `wc -l` ile aynı sayım: satır sonu sayısı (+ sonda satır sonu yoksa son satır).
static func count_lines(text: String) -> int:
	if text.is_empty():
		return 0
	var n = text.count("\n")
	if not text.ends_with("\n"):
		n += 1
	return n

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	var files: Array = []
	_collect(ROOT, files)
	var over_fail: Array = []
	var warned: Array = []
	for f in files:
		var rel = str(f).trim_prefix(ROOT + "/")
		var n = count_lines(FileAccess.get_file_as_string(f))
		var limit = FAIL_LIMIT
		if EXCEPTIONS.has(rel):
			limit = int((EXCEPTIONS[rel] as Dictionary).get("max", FAIL_LIMIT))
		if n > limit:
			over_fail.append("%s (%d > %d)" % [rel, n, limit])
		elif n > WARN_LIMIT:
			warned.append("%s (%d)" % [rel, n])
	if not warned.is_empty():
		print("  [LINE BUDGET] %d satırı aşan dosyalar (uyarı): %s" % [WARN_LIMIT, ", ".join(warned)])

	# Sayım wc -l ile aynı olmalı (sahte yeşili önler: dosya bulunamazsa ya da sayım bozuksa).
	var counting_ok = count_lines("a\nb\n") == 2 and count_lines("a\nb") == 2 and count_lines("") == 0
	if files.size() > 20 and counting_ok and over_fail.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("Satır bütçesi aşıldı (> %d, istisna yok): %s (dosya=%d sayım=%s)" % [FAIL_LIMIT, str(over_fail), files.size(), str(counting_ok)])

	# İstisna listesi bayatlamasın: tavanın altına inen / silinen dosya listeden çıkarılır.
	var stale: Array = []
	for rel in EXCEPTIONS.keys():
		var p = ROOT.path_join(str(rel))
		if not FileAccess.file_exists(p) or count_lines(FileAccess.get_file_as_string(p)) <= FAIL_LIMIT:
			stale.append(str(rel))
	if stale.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("EXCEPTIONS'ta artık gerekmeyen girişler: " + str(stale))

	return {"name": "LineBudgetTests", "passed": passed, "failed": failed, "errors": errors}
