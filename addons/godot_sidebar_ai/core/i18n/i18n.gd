@tool
extends RefCounted
class_name AISidebarI18n

## Çok Dilli Yerelleştirme Sözlüğü (TR / EN) (SRP).

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

## Metinler `addons/godot_sidebar_ai/i18n/<dil>.json` dosyalarındadır (i18next kaynak
## dosyaları gibi); ilk kullanımda okunur ve önbelleğe alınır.
const LOCALE_DIR = "res://addons/godot_sidebar_ai/i18n"
const SUPPORTED_LANGUAGES = ["tr", "en"]
const DEFAULT_LANGUAGE = "tr"

static var _strings_cache: Dictionary = {}

## Bir dilin sözlüğü (desteklenmeyen dil ya da okunamayan dosya: boş sözlük).
static func get_strings(lang: String) -> Dictionary:
	if _strings_cache.has(lang):
		return _strings_cache[lang]
	var dict: Dictionary = {}
	if lang in SUPPORTED_LANGUAGES:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOCALE_DIR.path_join(lang + ".json")))
		if parsed is Dictionary:
			dict = parsed
	_strings_cache[lang] = dict
	return dict

static func get_current_language() -> String:
	var cfg = AISidebarConfig.load_config()
	return cfg.get("language", "tr")

static func set_language(lang: String) -> void:
	if lang != "tr" and lang != "en":
		lang = "tr"
	var cfg = AISidebarConfig.load_config()
	cfg["language"] = lang
	AISidebarConfig.save_config(cfg)

static func toggle_language() -> String:
	var current = get_current_language()
	var next_lang = "en" if current == "tr" else "tr"
	set_language(next_lang)
	return next_lang

static func get_text(key: String, params: Dictionary = {}) -> String:
	return translate(get_current_language(), key, params)

## Verilen dilde çeviri (config okumaz/yazmaz; testler ve dil önizlemesi için).
static func translate(lang: String, key: String, params: Dictionary = {}) -> String:
	var fallback: Dictionary = get_strings(DEFAULT_LANGUAGE)
	var dict: Dictionary = get_strings(lang) if lang in SUPPORTED_LANGUAGES else fallback
	var val: String = dict.get(key, fallback.get(key, key))
	
	for p_key in params.keys():
		val = val.replace("{" + str(p_key) + "}", str(params[p_key]))
		
	return val

## Bir dildeki tüm anahtarlar (sıralı).
static func get_keys(lang: String) -> Array:
	var keys: Array = get_strings(lang).keys()
	keys.sort()
	return keys
