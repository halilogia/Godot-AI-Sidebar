@tool
extends SceneTree

## Sıkı GDScript uyarı raporu + cırcır (Refactor Faz 4.A.3 / 4.A.4).
##
## Godot 4.7 headless'ta uyarılar seviye 1'de (WARN) hiçbir yere basılmaz; yalnızca
## seviye 2'de (ERROR) "Warning treated as error" olarak görünür (docs/KNOWLEDGE.md).
## Bu yüzden ölçüm bir alt süreçte yapılır:
##   1. Eklentinin tüm betikleri varsayılan ayarlarla yüklenir (önbellek temiz derlenir).
##   2. Her uyarı türü için yalnızca o tür seviye 2'ye çekilir (ayar bir kare sonra etkin olur).
##   3. Her betik yerinde reload(true) ile yeniden derlenir; bağımlılıklar önbellekten
##      geldiği için hata zincirlenmez. Dosya/tür işaretleri stderr'e basılır.
## Üst süreç alt sürecin çıktısını sayar, TYPECHECK_BASELINE ile karşılaştırır:
## bir dosyada bir türün sayısı artarsa (yeni dosyada > 0 dahil) başarısız olur.
##
## Kullanım: godot --headless --path . -s res://tools/warning_report.gd [-- --update-baseline]

const ROOT = "res://addons/godot_sidebar_ai"
const BASELINE = "res://tools/typecheck_baseline.json"
const WARNINGS = ["untyped_declaration", "unsafe_method_access", "unsafe_property_access", "unsafe_call_argument", "unsafe_cast"]
const MARK_FILE = "@@WARN_FILE "
const MARK_DONE = "@@WARN_DONE"
const TREATED = "(Warning treated as error.)"

func _initialize() -> void:
	var user_args = OS.get_cmdline_user_args()
	if "--child" in user_args:
		await _run_child()
	else:
		_run_parent("--update-baseline" in user_args)

static func collect(path: String, out: Array) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(path.path_join(f))
	for d in dir.get_directories():
		collect(path.path_join(d), out)

func _set_levels(active: String) -> void:
	for w in WARNINGS:
		ProjectSettings.set_setting("debug/gdscript/warnings/" + w, 2 if w == active else 0)
	ProjectSettings.set_setting("debug/gdscript/warnings/directory_rules", {"res://addons": 1})

func _run_child() -> void:
	var files: Array = []
	collect(ROOT, files)
	files.sort()
	_set_levels("")
	await process_frame
	await process_frame
	var scripts: Dictionary = {}
	for f in files:
		var s = load(f)
		if s is GDScript:
			scripts[f] = s
	for w in WARNINGS:
		_set_levels(w)
		await process_frame
		await process_frame
		for f in files:
			printerr(MARK_FILE + w + " " + f)
			if scripts.has(f):
				(scripts[f] as GDScript).reload(true)
	printerr(MARK_DONE)
	quit(0)

## Alt süreç çıktısını {dosya: {tür: sayı}} sözlüğüne çevirir (saf; test edilebilir).
static func parse_output(text: String) -> Dictionary:
	var counts: Dictionary = {}
	var cur_file = ""
	var cur_warn = ""
	for line in text.split("\n"):
		var l = line.strip_edges()
		if l.begins_with(MARK_FILE):
			var rest = l.trim_prefix(MARK_FILE)
			var sp = rest.find(" ")
			cur_warn = rest.left(sp)
			cur_file = rest.substr(sp + 1).trim_prefix(ROOT + "/")
		elif l.contains(TREATED) and not cur_file.is_empty():
			if not counts.has(cur_file):
				counts[cur_file] = {}
			counts[cur_file][cur_warn] = int(counts[cur_file].get(cur_warn, 0)) + 1
	return counts

## Artışları listeler: taban dosyada yoksa taban 0 kabul edilir (yeni dosya sıfırdan başlar).
static func regressions(now: Dictionary, base: Dictionary) -> Array:
	var out: Array = []
	for f in now.keys():
		for w in (now[f] as Dictionary).keys():
			var n = int(now[f][w])
			var b = int((base.get(f, {}) as Dictionary).get(w, 0))
			if n > b:
				out.append("%s %s: %d > %d" % [f, w, n, b])
	out.sort()
	return out

static func total(counts: Dictionary, warn: String = "") -> int:
	var t = 0
	for f in counts.keys():
		for w in (counts[f] as Dictionary).keys():
			if warn.is_empty() or w == warn:
				t += int(counts[f][w])
	return t

func _run_parent(update_baseline: bool) -> void:
	var out: Array = []
	var args = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/warning_report.gd", "--", "--child"]
	var code = OS.execute(OS.get_executable_path(), args, out, true)
	var text = "\n".join(PackedStringArray(out))
	if code != 0 or not text.contains(MARK_DONE):
		printerr("❌ [WARNINGS FAILED] Alt süreç tamamlanmadı (exit=%d)." % code)
		quit(1)
		return
	var counts = parse_output(text)
	print("==================================================")
	print("  GDScript Sıkı Uyarı Raporu (addons/godot_sidebar_ai)")
	print("==================================================")
	for w in WARNINGS:
		print(" - %-24s: %d" % [w, total(counts, w)])
	print(" - %-24s: %d dosyada %d" % ["TOPLAM", counts.size(), total(counts)])
	if update_baseline:
		var f = FileAccess.open(BASELINE, FileAccess.WRITE)
		f.store_string(JSON.stringify(_sorted(counts), "  ", false) + "\n")
		f.close()
		print("Baseline yazıldı: " + BASELINE)
		quit(0)
		return
	var base_text = FileAccess.get_file_as_string(BASELINE)
	var base = JSON.parse_string(base_text) if not base_text.is_empty() else null
	if not (base is Dictionary):
		printerr("❌ [WARNINGS FAILED] Baseline okunamadı: " + BASELINE)
		quit(1)
		return
	var regs = regressions(counts, base)
	var improved = total(base) - total(counts)
	if not regs.is_empty():
		printerr("❌ [WARNINGS FAILED] Uyarı sayısı artan dosyalar (%d):" % regs.size())
		for r in regs:
			printerr("   * " + r)
		quit(1)
		return
	if improved > 0:
		print("✓ %d uyarı azaldı; baseline'ı düşürmek için: -- --update-baseline" % improved)
	print("🎉 [WARNINGS OK] Hiçbir dosyada uyarı sayısı artmadı.")
	quit(0)

static func _sorted(counts: Dictionary) -> Dictionary:
	var keys = counts.keys()
	keys.sort()
	var out: Dictionary = {}
	for k in keys:
		var inner: Dictionary = {}
		for w in WARNINGS:
			if (counts[k] as Dictionary).has(w):
				inner[w] = counts[k][w]
		out[k] = inner
	return out
