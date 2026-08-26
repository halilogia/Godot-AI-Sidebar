@tool
extends RefCounted
class_name AISidebarI18n

## Çok Dilli Yerelleştirme Sözlüğü (TR / EN) (SRP).

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

const STRINGS: Dictionary = {
	"tr": {
		"app_title": "Godot AI Core",
		"status_ready": "● Hazır",
		"status_thinking": "● AI Düşünüyor...",
		"status_refreshing": "● Modeller Çekiliyor...",
		"status_executing": "● Araçlar Çalıştırılıyor ({step}/{max})...",
		"btn_send": "Gönder",
		"btn_stop": "Durdur",
		"btn_clear": "Temizle",
		"input_placeholder": "AI asistanınıza Godot ile ilgili bir görev verin...",
		"tooltip_lang": "Dili Değiştir (TR / EN)",
		"tooltip_model": "Aktif AI Modeli",
		"tooltip_refresh": "Modelleri 9Router'dan Yenile",
		"tooltip_settings": "9Router / AI API Ayarları",
		"tooltip_stop": "Ajanın çalışmasını hemen durdur",
		"sender_user": "Sen",
		"sender_assistant": "Godot AI",
		"sender_tool": "🛠️ Motor Aracı",
		"sender_result": " Sonuç",
		"sender_error": " Hata",
		"thinking_title": "Düşünce Süreci",
		"agent_stopped": "Ajan kullanıcı tarafından durduruldu.",
		"tool_executing": "Araç çalıştırılıyor: {tool}...",
		"tool_success": "İşlem başarılı: {result}",
		"tool_error": "İşlem başarısız: {error}",
		"settings_title": "⚙️ 9Router / AI API Ayarları",
		"btn_save_close": "Kaydet ve Kapat",
		"label_base_url": "9Router / API Base URL:",
		"label_api_key": "API Key (9Router için opsiyonel):",
		"label_temperature": "Sıcaklık (Temperature):",
		"label_max_iterations": "Maksimum Ajan Adımı (Loop Limit):",
		"label_system_prompt": "Sistem Promptu:",
		"placeholder_base_url": "http://localhost:20128/v1 veya https://openrouter.ai/api/v1"
	},
	"en": {
		"app_title": "Godot AI Core",
		"status_ready": "● Ready",
		"status_thinking": "● AI Thinking...",
		"status_refreshing": "● Fetching Models...",
		"status_executing": "● Executing Tools ({step}/{max})...",
		"btn_send": "Send",
		"btn_stop": "Stop",
		"btn_clear": "Clear",
		"input_placeholder": "Give your AI assistant a Godot task...",
		"tooltip_lang": "Switch Language (TR / EN)",
		"tooltip_model": "Active AI Model",
		"tooltip_refresh": "Refresh Models from 9Router",
		"tooltip_settings": "9Router / AI API Settings",
		"tooltip_stop": "Immediately stop agent loop",
		"sender_user": "You",
		"sender_assistant": "Godot AI",
		"sender_tool": "🛠️ Engine Tool",
		"sender_result": " Result",
		"sender_error": " Error",
		"thinking_title": "Thought Process",
		"agent_stopped": "Agent stopped by user.",
		"tool_executing": "Executing tool: {tool}...",
		"tool_success": "Success: {result}",
		"tool_error": "Failed: {error}",
		"settings_title": "⚙️ 9Router / AI API Settings",
		"btn_save_close": "Save & Close",
		"label_base_url": "9Router / API Base URL:",
		"label_api_key": "API Key (Optional for 9Router):",
		"label_temperature": "Temperature:",
		"label_max_iterations": "Max Agent Iterations (Loop Limit):",
		"label_system_prompt": "System Prompt:",
		"placeholder_base_url": "http://localhost:20128/v1 or https://openrouter.ai/api/v1"
	}
}

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
	var lang = get_current_language()
	var dict = STRINGS.get(lang, STRINGS["tr"])
	var val: String = dict.get(key, STRINGS["tr"].get(key, key))
	
	for p_key in params.keys():
		val = val.replace("{" + str(p_key) + "}", str(params[p_key]))
		
	return val
