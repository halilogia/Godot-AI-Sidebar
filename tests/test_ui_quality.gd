@tool
extends RefCounted

## Kural (CLAUDE.md → Arayüz grafik kalitesi standardı): geliştirici ajanın kuralının altyapısı.
##   T1 Cırcır: ui/ altındaki .gd dosyalarında şunlar dosya başına BASELINE'ı aşamaz (yeni dosya sıfırla başlar):
##      fixed_font_size     add_theme_font_size_override("font_size", 11)        → tip varyasyonu ya da fs()
##      unscaled_font_size  ..., AISidebarTheme.FONT_SIZE_BODY)                  → AISidebarTheme.fs(...)
##      color_literal       Color(0.9, ...)                                       → AISidebarTheme renk belirteci
##      bbcode_hex_color    "[color=#88c0d0]"                                     → AISidebarTheme.bb(belirteç)
##      literal_spacing     add_theme_constant_override("separation", 6)         → AISidebarTheme.px(SPACE_*)
##      unscaled_spacing    ..., AISidebarTheme.SPACE_SM)                         → AISidebarTheme.px(...)
##      literal_icon_size   apply_tinted_icon(b, "x", c, 12)                      → AISidebarTheme.ICON_SIZE_*
##      font_size_override  add_theme_font_size_override(...) herhangi biri        → tip varyasyonu (yazı boyu temada)
##      stylebox_override   add_theme_stylebox_override(...) herhangi biri         → tip varyasyonu (istisna: veriden
##                          gelen renkli haplar, BASELINE'da gerekçesiyle)
##   T2 Ayarlar sayfaları ortak setle (settings_ui_kit.gd) kurulur, kendi yazı boyunu seçmez ve açılır
##      listeyi setten alır (en uzun seçeneğe göre genişleyip pencereyi ekran dışına itmesin).
##   T3 Sayaç kendini doğrular.
##   T4 ui/ sahnelerinde (.tscn) sabit tema geçersiz kılması yoktur (yazı boyu, renk, boşluk kodda ölçekli verilir).
##   T5 Tema üreticisi her varyasyonu gerçekten tanımlar (adı sabitte olan varyasyonun temel tipi vardır).

const UI_ROOT := "res://addons/godot_sidebar_ai/ui"
const THEME_FILES: Array[String] = ["theme/sidebar_theme.gd", "theme/sidebar_theme_builder.gd"]
const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const VARIATIONS: Array[String] = [
	AISidebarThemeBuilder.TITLE, AISidebarThemeBuilder.BODY, AISidebarThemeBuilder.HINT, AISidebarThemeBuilder.MICRO,
	AISidebarThemeBuilder.TITLE_WARNING, AISidebarThemeBuilder.TITLE_ERROR, AISidebarThemeBuilder.TITLE_INFO,
	AISidebarThemeBuilder.TEXT_SUCCESS, AISidebarThemeBuilder.TEXT_ERROR,
	AISidebarThemeBuilder.RICH_BODY, AISidebarThemeBuilder.RICH_SMALL, AISidebarThemeBuilder.RICH_TITLE,
	AISidebarThemeBuilder.CARD, AISidebarThemeBuilder.CARD_WARNING, AISidebarThemeBuilder.CARD_QUESTION,
	AISidebarThemeBuilder.CARD_ERROR, AISidebarThemeBuilder.CARD_INFO, AISidebarThemeBuilder.CARD_NEUTRAL,
	AISidebarThemeBuilder.CARD_SUBTLE, AISidebarThemeBuilder.CARD_INSET,
	AISidebarThemeBuilder.CARD_APPROVAL, AISidebarThemeBuilder.CARD_APPROVAL_DANGER, AISidebarThemeBuilder.CARD_APPROVAL_DONE,
	AISidebarThemeBuilder.CODE_BOX, AISidebarThemeBuilder.ICON_CHIP_WARNING, AISidebarThemeBuilder.ICON_CHIP_DANGER, AISidebarThemeBuilder.ICON_CHIP_SUCCESS,
	AISidebarThemeBuilder.APPROVE_BUTTON, AISidebarThemeBuilder.APPROVE_DANGER_BUTTON,
	AISidebarThemeBuilder.BUTTON, AISidebarThemeBuilder.PRIMARY_BUTTON, AISidebarThemeBuilder.DANGER_BUTTON,
	AISidebarThemeBuilder.GHOST_BUTTON, AISidebarThemeBuilder.OPTION_BUTTON, AISidebarThemeBuilder.LINK_BUTTON,
	AISidebarThemeBuilder.NAV_BUTTON, AISidebarThemeBuilder.NAV_BUTTON_ACTIVE,
	AISidebarThemeBuilder.LINE_EDIT, AISidebarThemeBuilder.TEXT_EDIT,
]
const KIT := "res://addons/godot_sidebar_ai/ui/components/settings_ui_kit.gd"

## İzinli sayılar; yalnız aşağı çekilir. Kalan istisnalar veriden gelen renkli haplardır (rengi moda /
## riske / kapsama göre çalışma anında seçilir, tema varyasyonu olamaz).
const BASELINE := {
	"components/approval_card.gd": {"stylebox_override": 1},
	"components/settings_ui_kit.gd": {"stylebox_override": 1},
	"controllers/model_bar_controller.gd": {"stylebox_override": 3},
}

const PATTERNS := {
	"fixed_font_size": "font_size\"\\s*,\\s*\\d",
	"unscaled_font_size": "font_size\"\\s*,\\s*AISidebarTheme\\.FONT_SIZE",
	"color_literal": "\\bColor8?\\(\\s*[0-9.]",
	"bbcode_hex_color": "\\[color=#[0-9a-fA-F]",
	"literal_spacing": "constant_override\\(\"[a-z_]+\",\\s*\\d",
	"unscaled_spacing": "constant_override\\(\"[a-z_]+\",\\s*AISidebarTheme\\.SPACE",
	"font_size_override": "add_theme_font_size_override\\(",
	"stylebox_override": "add_theme_stylebox_override\\(",
	"literal_icon_size":"(?:tinted_icon|make_icon_rect|set_rect_icon|StatusIcon\\.new|get_status_icon)\\([^)]*[ (]\\d+\\)",
}

const SETTINGS_PAGES: Array[String] = [
	"dialogs/settings_dialog.gd",
	"components/settings_general_pages.gd",
	"components/rules_view.gd",
	"components/skills_view.gd",
	"components/mcp_settings_view.gd",
]

static func _files(dir: String, ext: String, out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_files(dir.path_join(d), ext, out)

static func count_violations(source: String) -> Dictionary:
	var res := {}
	var counts := {}
	for kind: String in PATTERNS.keys():
		var re := RegEx.new()
		re.compile(str(PATTERNS[kind]))
		res[kind] = re
		counts[kind] = 0
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		for kind: String in PATTERNS.keys():
			var re: RegEx = res[kind]
			counts[kind] = int(counts[kind]) + re.search_all(line).size()
	return counts

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	var files: Array[String] = []
	_files(UI_ROOT, ".gd", files)
	var over: Array[String] = []
	var lower: Array[String] = []
	for path: String in files:
		var rel := path.trim_prefix(UI_ROOT + "/")
		if THEME_FILES.has(rel):
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
		errors.append("T1 UI quality ratchet (use theme type variations / AISidebarTheme.fs / px / bb and color tokens instead of literals): " + ", ".join(PackedStringArray(over)))
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

	# T3 Sayaç kendini doğrular: her ihlal türü yakalanır, belirteç kullanımı ve yorum yakalanmaz.
	var probe := count_violations("\n".join(PackedStringArray([
		"l.add_theme_font_size_override(\"font_size\", 11)",
		"l.add_theme_font_size_override(\"font_size\", AISidebarTheme.FONT_SIZE_BODY)",
		"x = Color(0.9, 0.1, 0.1)",
		"t = \"[color=#88c0d0]\" + s",
		"b.add_theme_constant_override(\"separation\", 6)",
		"b.add_theme_constant_override(\"separation\", AISidebarTheme.SPACE_SM)",
		"ok = AISidebarTheme.fs(AISidebarTheme.FONT_SIZE_BODY) + AISidebarTheme.px(AISidebarTheme.SPACE_SM)",
		"c = AISidebarTheme.bb(AISidebarTheme.COLOR_ACCENT)",
		"AISidebarIconHelper.apply_tinted_icon(b, \"x\", AISidebarTheme.COLOR_ERROR, 12)",
		"AISidebarIconHelper.apply_tinted_icon(b, \"x\", AISidebarTheme.COLOR_ERROR, AISidebarTheme.ICON_SIZE_SM)",
		"p.add_theme_stylebox_override(\"panel\", s)",
		"# Color(1, 1, 1)",
	])))
	# Yazı boyu geçersiz kılması iki örnek satırda geçer; her tür en az bir kez yakalanır.
	var expected := {"font_size_override": 2}
	var all_one := true
	for kind: String in PATTERNS.keys():
		if int(probe[kind]) != int(expected.get(kind, 1)):
			all_one = false
	if all_one:
		passed += 1
	else:
		failed += 1
		errors.append("T3 counter self-check failed: " + str(probe))

	# T4 Sahnelerde sabit tema geçersiz kılması yok.
	var scenes: Array[String] = []
	_files(UI_ROOT, ".tscn", scenes)
	var scene_hits: Array[String] = []
	for path: String in scenes:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			if line.begins_with("theme_override_font_sizes/") or line.begins_with("theme_override_colors/") or line.begins_with("theme_override_constants/"):
				scene_hits.append(path.get_file() + ": " + line)
	if scene_hits.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T4 fixed theme overrides in scenes (set them scaled in code): " + ", ".join(PackedStringArray(scene_hits)))

	# T5 Tema üreticisinin her varyasyonu tanımlı ve temel tipi var.
	var theme := AISidebarThemeBuilder.build(AISidebarThemeBuilder.Density.COMPACT)
	var missing: Array[String] = []
	for v: String in VARIATIONS:
		if theme.get_type_variation_base(v) == &"":
			missing.append(v)
	if missing.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T5 theme variations without a base type: " + ", ".join(PackedStringArray(missing)))

	# T6 Açık / koyu palet: iki palet aynı renk adlarını tanımlar, açık palette yazı koyu / zemin açık,
	# koyu palette tersi; tema iki palette de kurulur ve varyasyonlar paletin rengini alır.
	var AISidebarTheme: GDScript = load("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
	var dark: Dictionary = AISidebarTheme.get("PALETTE_DARK")
	var light: Dictionary = AISidebarTheme.get("PALETTE_LIGHT")
	var same_keys := dark.keys().size() == light.keys().size() and dark.keys().all(func(k: Variant) -> bool: return light.has(k))
	AISidebarTheme.call("use_palette", true)
	var light_text: Color = AISidebarTheme.get("COLOR_TEXT_PRIMARY")
	var light_bg: Color = AISidebarTheme.get("COLOR_BG_APP")
	var light_theme := AISidebarThemeBuilder.build()
	var light_body: Color = light_theme.get_color("font_color", AISidebarThemeBuilder.BODY)
	AISidebarTheme.call("use_palette", false)
	var dark_text: Color = AISidebarTheme.get("COLOR_TEXT_PRIMARY")
	var dark_bg: Color = AISidebarTheme.get("COLOR_BG_APP")
	if same_keys and light_text.get_luminance() < 0.3 and light_bg.get_luminance() > 0.8 and dark_text.get_luminance() > 0.7 and dark_bg.get_luminance() < 0.2 and light_body == light_text:
		passed += 1
	else:
		failed += 1
		errors.append("T6 palettes: keys=%s light=%s/%s dark=%s/%s body=%s" % [same_keys, light_text, light_bg, dark_text, dark_bg, light_body])

	return {"name": "UiQualityTests", "passed": passed, "failed": failed, "errors": errors}
