@tool
extends RefCounted

## Kural (AGENTS.md §3.8): Ayarlar güncel kalır. config.json'daki her kullanıcı ayarının bir arayüz
## denetimi vardır; arayüzsüz yeni ayar ya da ölü varsayılan bu testi kırmızı yapar.

const AISidebarSettingsCatalog = preload("res://addons/godot_sidebar_ai/core/config/settings_catalog.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

const ADDON := "res://addons/godot_sidebar_ai"

static func _gd_files(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_gd_files(dir.path_join(d), out)

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	var files: Array = []
	_gd_files(ADDON, files)
	var sources := {}
	for p in files:
		sources[p] = FileAccess.get_file_as_string(p)

	# Kodun config'e yazdığı anahtarlar: cfg["x"] = / config["x"] =
	var written := {}
	var re := RegEx.new()
	re.compile("(?:cfg|config)\\[\"([a-z_]+)\"\\]\\s*=")
	for p in sources.keys():
		for m in re.search_all(str(sources[p])):
			written[m.get_string(1)] = p

	var known := {}
	for k in AISidebarSettingsCatalog.UI_KEYS.keys():
		known[k] = true
	for k in AISidebarSettingsCatalog.INTERNAL_KEYS.keys():
		known[k] = true

	# 1. Her varsayılan ve yazılan anahtar katalogda (arayüzü var ya da iç ayar).
	var missing: Array = []
	for k in AISidebarConfig.DEFAULT_CONFIG.keys():
		if not known.has(k):
			missing.append("%s (default)" % k)
	for k in written.keys():
		if not known.has(k):
			missing.append("%s (written in %s)" % [k, str(written[k]).get_file()])
	if missing.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T1 settings without a UI control (add a control and a catalog entry, or mark as internal): " + str(missing))

	# 2. Katalogdaki her arayüz anahtarı gerçekten bir ui/ dosyasında ya da arayüzün kullandığı
	# kontrol yüzeyinde (köprü, skill kaydı) okunur / yazılır; katalogdaki "ölü" satırlar yakalanır.
	var ui_text := ""
	for p in sources.keys():
		var path := str(p)
		if path.contains("/ui/") or path.ends_with("mcp_bridge_control.gd") or path.ends_with("external_agent_gateway.gd") or path.ends_with("skill_registry.gd"):
			ui_text += str(sources[p])
	var unused: Array = []
	for k in AISidebarSettingsCatalog.UI_KEYS.keys():
		if not ui_text.contains("\"%s\"" % k) and not (k == "skills_enabled" and ui_text.contains("PREFS_KEY")):
			unused.append(k)
	if unused.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("T2 catalog keys with no UI code: " + str(unused))

	return {"name": "SettingsCoverageTests", "passed": passed, "failed": failed, "errors": errors}
