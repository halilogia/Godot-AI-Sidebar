@tool
extends RefCounted

## i18n (Refactor Faz 5): sözlük içeriğinin sabitlenmesi ve denetimleri.
## Dil config'ten okunmaz: `translate(lang, …)` kullanılır, kullanıcının config.json'una dokunulmaz.

const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")

const ROOT = "res://addons/godot_sidebar_ai"
const LANGS = ["tr", "en"]

static func _collect(path: String, out: Array) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(path.path_join(f))
	for d in dir.get_directories():
		_collect(path.path_join(d), out)

static func _placeholders(text: String) -> Array:
	var out: Array = []
	for m in RegEx.create_from_string("\\{([a-z_]+)\\}").search_all(text):
		if not out.has(m.get_string(1)):
			out.append(m.get_string(1))
	out.sort()
	return out

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Sabitleme: her (dil, anahtar) → metin eşlemesi + yedekleme ve parametre davranışı.
	var trace: Array = []
	for lang in LANGS:
		for key in AISidebarI18n.get_keys(lang):
			trace.append([lang, key, AISidebarI18n.translate(lang, key)])
	trace.append(["de", "status_ready", AISidebarI18n.translate("de", "status_ready")])
	trace.append(["en", "__missing__", AISidebarI18n.translate("en", "__missing__")])
	trace.append(["tr", "status_executing", AISidebarI18n.translate("tr", "status_executing", {"step": 2, "max": 5})])
	var digest = JSON.stringify(trace).md5_text()
	var golden = "614cdecbb39a6e36f1417f1a2d63241e"
	if trace.size() > 100 and digest == golden:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (i18n golden) failed: entries=%d digest=%s" % [trace.size(), digest])

	# 2. TR / EN anahtar eşitliği (5.3a)
	var tr_keys = AISidebarI18n.get_keys("tr")
	var en_keys = AISidebarI18n.get_keys("en")
	if tr_keys == en_keys and not tr_keys.is_empty():
		passed += 1
	else:
		var only_tr: Array = tr_keys.filter(func(k): return not en_keys.has(k))
		var only_en: Array = en_keys.filter(func(k): return not tr_keys.has(k))
		failed += 1
		errors.append("T2 (key parity) failed: only_tr=%s only_en=%s" % [str(only_tr), str(only_en)])

	# 3. Kodda get_text / translate ile sabit anahtarla istenen her anahtar tanımlı (5.3b)
	var files: Array = []
	_collect(ROOT, files)
	var used_re = RegEx.create_from_string("(?:get_text|translate)\\((?:\"[a-z]{2}\"\\s*,\\s*)?\"([A-Za-z0-9_]+)\"")
	var undefined: Array = []
	var all_src = ""
	for f in files:
		if str(f).get_file() == "i18n.gd":
			continue  # sözlüğün kendisi anahtarları tırnaklı içerir
		var src = FileAccess.get_file_as_string(f)
		all_src += src + "\n"
		for m in used_re.search_all(src):
			var k = m.get_string(1)
			if not tr_keys.has(k) and not undefined.has(k):
				undefined.append(str(f).get_file() + ":" + k)
	if undefined.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T3 (undefined keys used) failed: " + str(undefined))

	# 4. {param} yer tutucuları iki dilde aynı (5.3d)
	var ph_bad: Array = []
	for key in tr_keys:
		if en_keys.has(key) and _placeholders(AISidebarI18n.translate("tr", key)) != _placeholders(AISidebarI18n.translate("en", key)):
			ph_bad.append(key)
	if ph_bad.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T4 (placeholder parity) failed: " + str(ph_bad))

	# 5. Kullanılmayan anahtar raporu (5.3c): eklenti kaynağında tırnaklı olarak hiç geçmeyen
	# anahtarlar yazdırılır (dinamik anahtarlar da tırnaklı geçtiği için sayılır). Başarısız saymaz.
	var unused: Array = []
	for key in tr_keys:
		if not all_src.contains("\"" + str(key) + "\""):
			unused.append(key)
	if not unused.is_empty():
		print("  [I18N] Kodda geçmeyen %d anahtar: %s" % [unused.size(), ", ".join(PackedStringArray(unused))])
	passed += 1

	return {"name": "I18nTests", "passed": passed, "failed": failed, "errors": errors}
