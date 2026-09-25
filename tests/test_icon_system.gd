@tool
extends RefCounted

## İkon sistemi testleri: Lucide SVG boyama, durum glifi → ikon eşlemesi, StatusIcon
## fallback'i ve UI kaynaklarına emoji geri girmemesi (premium arayüz kuralı).

const AISidebarIconHelper = preload("res://addons/godot_sidebar_ai/ui/components/icon_helper.gd")
const AISidebarStatusIcon = preload("res://addons/godot_sidebar_ai/ui/components/status_icon.gd")
const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")

## UI'da yasak piktografik karakterler. Veri glifleri (✓ ✕ ▶ ! ☐ – •) serbesttir:
## modelde kalır, StatusIcon tarafından ikona çevrilir.
const BANNED_CHARS = ["❓", "❗", "⏸", "⚡", "✨", "✅", "❌", "ℹ", "⭐"]

static func _has_banned(line: String) -> bool:
	for ch in BANNED_CHARS:
		if ch in line:
			return true
	for i in line.length():
		var c = line.unicode_at(i)
		if (c >= 0x1F000 and c <= 0x1FAFF) or c == 0xFE0F:
			return true
	return false

static func _scan_dir(path: String, out: Array) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			var file_path = path.path_join(f)
			var lines = FileAccess.get_file_as_string(file_path).split("\n")
			for i in lines.size():
				var stripped = lines[i].strip_edges()
				if stripped.begins_with("#"):
					continue
				if _has_banned(stripped):
					out.append("%s:%d" % [file_path, i + 1])
	for d in dir.get_directories():
		_scan_dir(path.path_join(d), out)

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	# 1. Boyalı ikon istenen boyutta ve renkte üretilir; bilinmeyen ikon null
	var red = Color(1, 0, 0)
	var tex = AISidebarIconHelper.get_tinted_icon("check", red, 16)
	var red_px = false
	if tex:
		var img = tex.get_image()
		for y in img.get_height():
			for x in img.get_width():
				var p = img.get_pixel(x, y)
				if p.a > 0.5 and p.r > 0.8 and p.g < 0.2 and p.b < 0.2:
					red_px = true
	if tex and tex.get_width() == 16 and red_px and AISidebarIconHelper.get_tinted_icon("__yok__", red) == null:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (tinted icon) failed: tex=%s red=%s" % [str(tex), str(red_px)])

	# 2. Her durum glifi için eşlenen ikon dosyası mevcut ve render ediliyor
	var missing: Array = []
	for g in ["✓", "✕", "▶", "!", "☐", "–", "•"]:
		if AISidebarIconHelper.get_status_icon(g) == null:
			missing.append(g)
	for n in ["list-checks", "message-circle-question-mark", "shield-alert", "monitor", "gamepad-2", "arrow-up-right", "arrow-down", "triangle-alert", "x"]:
		if AISidebarIconHelper.get_tinted_icon(n, Color.WHITE) == null:
			missing.append(n)
	if missing.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T2 (status/icon files) failed: " + str(missing))

	# 3. StatusIcon: bilinen glif ikon, bilinmeyen glif metin (sessiz kayıp yok)
	var si = AISidebarStatusIcon.new()
	si.set_status("✓")
	var known_ok = si.has_icon() and not si._fallback.visible
	si.set_status("?")
	var fallback_ok = not si.has_icon() and si._fallback.visible and si._fallback.text == "?"
	si.free()
	if known_ok and fallback_ok:
		passed += 1
	else:
		failed += 1
		errors.append("T3 (StatusIcon fallback) failed: known=%s fallback=%s" % [str(known_ok), str(fallback_ok)])

	# 4. Activity satırı veri glifini korur, görünümde ikon çizer
	var grp = AISidebarActivityGroup.new(true)
	grp._ready()
	var idx = grp.add_activity("✓", "Read script", 10)
	var row_icon = grp._item_rows[idx].get("icon")
	if grp.get_item(idx).get("icon", "") == "✓" and row_icon is AISidebarStatusIcon and row_icon.has_icon():
		passed += 1
	else:
		failed += 1
		errors.append("T4 (activity row icon) failed.")
	grp.free()

	# 5. UI kaynaklarında emoji yok (yorum satırları hariç)
	var hits: Array = []
	_scan_dir("res://addons/godot_sidebar_ai/ui", hits)
	_scan_dir("res://addons/godot_sidebar_ai/core/commands", hits)
	if hits.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T5 (no emoji in UI) failed: " + str(hits))

	return {"name": "IconSystemTests", "passed": passed, "failed": failed, "errors": errors}
