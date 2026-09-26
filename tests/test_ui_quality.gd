@tool
extends RefCounted

## Kural (CLAUDE.md → Arayüz grafik kalitesi standardı): geliştirici ajanın kuralının altyapısı.
##   T1 Cırcır: ui/ altındaki .gd dosyalarında sabit piksel yazı boyu (add_theme_font_size_override("font_size", 11))
##      ve tema dışı renk sabiti (Color(0.9, ...)) sayısı dosya başına BASELINE'ı aşamaz; yeni dosya sıfırla
##      başlar. Renk / boşluk / köşe AISidebarTheme belirteçlerinden, yazı boyu tema belirtecinden ya da
##      AISidebarSettingsUi'den (editör yazı boyuyla ölçeklenir) gelir. Bir dosyayı temizlediysen sayısını düşür.
##   T2 Ayarlar sayfaları ortak bileşen setiyle (settings_ui_kit.gd) kurulur, kendi yazı boyunu seçmez ve
##      açılır listeyi setten alır (en uzun seçeneğe göre genişleyip pencereyi ekran dışına itmesin).

const UI_ROOT := "res://addons/godot_sidebar_ai/ui"
const THEME_FILE := "theme/sidebar_theme.gd"
const KIT := "res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd"

## Standarttan önce yazılmış dosyaların mevcut sayıları; yalnız aşağı çekilir.
const BASELINE := {
	"components/approval_card.gd": {"fixed_font_size": 5, "color_literal": 9},
	"components/changes_card.gd": {"fixed_font_size": 5, "color_literal": 2},
	"components/clarification_card.gd": {"fixed_font_size": 6, "color_literal": 9},
	"components/error_card.gd": {"fixed_font_size": 3, "color_literal": 4},
	"components/message_queue_panel.gd": {"fixed_font_size": 3, "color_literal": 0},
	"components/plan_card.gd": {"fixed_font_size": 4, "color_literal": 8},
	"components/runtime_card.gd": {"fixed_font_size": 2, "color_literal": 3},
	"components/telemetry_card.gd": {"fixed_font_size": 3, "color_literal": 3},
	"components/welcome_card.gd": {"fixed_font_size": 0, "color_literal": 2},
}

const SETTINGS_PAGES: Array[String] = [
	"dialogs/settings_dialog.gd",
	"components/settings_general_pages.gd",
	"components/rules_view.gd",
	"components/skills_view.gd",
	"components/mcp_settings_view.gd",
]

static func _gd_files(dir: String, out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_gd_files(dir.path_join(d), out)

static func count_violations(source: String) -> Dictionary:
	var font_re := RegEx.new()
	font_re.compile("font_size\"\\s*,\\s*\\d")
	var color_re := RegEx.new()
	color_re.compile("\\bColor8?\\(\\s*[0-9.]")
	var counts := {"fixed_font_size": 0, "color_literal": 0}
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		counts["fixed_font_size"] = int(counts["fixed_font_size"]) + font_re.search_all(line).size()
		counts["color_literal"] = int(counts["color_literal"]) + color_re.search_all(line).size()
	return counts

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	var files: Array[String] = []
	_gd_files(UI_ROOT, files)
	var over: Array[String] = []
	var lower: Array[String] = []
	for path: String in files:
		var rel := path.trim_prefix(UI_ROOT + "/")
		if rel == THEME_FILE:
			continue
		var counts := count_violations(FileAccess.get_file_as_string(path))
		var base: Dictionary = BASELINE.get(rel, {})
		for kind: String in counts.keys():
			var now: int = counts[kind]
			var allowed: int = base.get(kind, 0)
			if now > allowed:
				over.append("%s %s: %d > %d" % [rel, kind, now, allowed])
			elif now < allowed:
				lower.append("%s %s: %d < %d" % [rel, kind, now, allowed])
	if over.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T1 UI quality ratchet (use AISidebarTheme tokens / AISidebarSettingsUi instead of literals): " + ", ".join(PackedStringArray(over)))
	if not lower.is_empty():
		print("  [UI] Sayı düştü, BASELINE'ı indir: " + ", ".join(PackedStringArray(lower)))

	var page_errors: Array[String] = []
	for rel: String in SETTINGS_PAGES:
		var src := FileAccess.get_file_as_string(UI_ROOT.path_join(rel))
		if not src.contains(KIT):
			page_errors.append(rel + " does not use settings_ui_kit.gd")
		if src.contains("add_theme_font_size_override"):
			page_errors.append(rel + " sets its own font size")
		if src.contains("OptionButton.new()"):
			page_errors.append(rel + " creates an OptionButton that grows to its longest item (use AISidebarSettingsUi.option_button())")
	if page_errors.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T2 settings pages: " + ", ".join(PackedStringArray(page_errors)))

	# T3 Sayaç kendini doğrular: sabit piksel ve renk sabiti yakalanır, tema belirteci ve yorum yakalanmaz.
	var probe := count_violations("l.add_theme_font_size_override(\"font_size\", 11)\nx = Color(0.9, 0.1, 0.1)\ny = AISidebarTheme.COLOR_ACCENT\n# Color(1, 1, 1)\nz = Color(AISidebarTheme.COLOR_ACCENT, 0.5)")
	if int(probe["fixed_font_size"]) == 1 and int(probe["color_literal"]) == 1:
		passed += 1
	else:
		failed += 1
		errors.append("T3 counter self-check failed: " + str(probe))

	return {"name": "UiQualityTests", "passed": passed, "failed": failed, "errors": errors}
