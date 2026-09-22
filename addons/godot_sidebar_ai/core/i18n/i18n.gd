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
		"status_agy_preparing": "● AGY hazırlanıyor...",
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
		"sender_tool": "Motor Aracı",
		"sender_result": " Sonuç",
		"sender_error": " Hata",
		"thinking_title": "Düşünce Süreci",
		"agent_stopped": "Ajan kullanıcı tarafından durduruldu.",
		"tool_executing": "Araç çalıştırılıyor: {tool}...",
		"tool_success": "İşlem başarılı: {result}",
		"tool_error": "İşlem başarısız: {error}",
		"settings_title": "Ayarlar",
		"btn_save_close": "Kaydet ve Kapat",
		"label_base_url": "9Router / API Base URL:",
		"label_api_key": "API Key (9Router için opsiyonel):",
		"label_temperature": "Sıcaklık (Temperature):",
		"label_max_iterations": "Maksimum Ajan Adımı (Loop Limit):",
		"label_system_prompt": "Sistem Promptu:",
		"placeholder_base_url": "http://localhost:20128/v1 veya https://openrouter.ai/api/v1",
		"mode_manual": "Manuel",
		"mode_auto": "Auto",
		"mode_full_auto": "Full Auto",
		"tooltip_approve_mode": "Onay Modu (Manuel / Auto / Full Auto)",
		"label_auto_approve_mode": "Auto Approve Modu:",
		"label_provider_type": "AI Sağlayıcı Modeli (Provider):",
		"provider_antigravity": "Google Antigravity CLI (Resmi, Yerel, Doğrudan Oturum)",
		"provider_openai": "OpenAI Uyumlu (9Router, Ollama, OpenRouter, LM Studio)",
		"hint_temp_ideal": "Kodlama ve mantıksal doğruluk için varsayılan: 0.20.",
		"btn_reset_temp": "0.20 (Varsayılan)",
		"tab_provider": "Sağlayıcı",
		"tab_parameters": "Model & Parametreler",
		"tab_appearance": "Görünüm & Dil",
		"tab_system_prompt": "Sistem Promptu",
		"label_language": "Arayüz Dili (Language):",
		"btn_reset_prompt": "Varsayılan Promptu Geri Yükle",
		"hint_prompt_reset": "Cerrahi dosya düzenleme ve araç odaklı varsayılan promptu yükler.",
		"history_title": "Sohbet Geçmişi",
		"history_search_placeholder": "Geçmiş sohbetlerde ara...",
		"history_empty": "Henüz kayıtlı geçmiş sohbet bulunmuyor.",
		"history_not_found": "Aramaya uygun sohbet bulunamadı.",
		"history_rename_title": "Sohbeti Yeniden Adlandır",
		"history_rename_prompt": "Yeni sohbet başlığını girin:",
		"history_delete_title": "Sohbeti Sil",
		"history_delete_prompt": "Bu sohbeti kalıcı olarak silmek istediğinize emin misiniz?",
		"history_btn_new": "+ Yeni Sohbet",
		"history_btn_close_tooltip": "Kapat ve Sohbete Dön",
		"history_tooltip_rename": "Yeniden Adlandır",
		"history_tooltip_delete": "Sil"
	},
	"en": {
		"app_title": "Godot AI Core",
		"status_ready": "● Ready",
		"status_thinking": "● AI Thinking...",
		"status_refreshing": "● Fetching Models...",
		"status_agy_preparing": "● AGY preparing...",
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
		"sender_tool": "Engine Tool",
		"sender_result": " Result",
		"sender_error": " Error",
		"thinking_title": "Thought Process",
		"agent_stopped": "Agent stopped by user.",
		"tool_executing": "Executing tool: {tool}...",
		"tool_success": "Success: {result}",
		"tool_error": "Failed: {error}",
		"settings_title": "Settings",
		"btn_save_close": "Save & Close",
		"label_base_url": "9Router / API Base URL:",
		"label_api_key": "API Key (Optional for 9Router):",
		"label_temperature": "Temperature:",
		"label_max_iterations": "Max Agent Iterations (Loop Limit):",
		"label_system_prompt": "System Prompt:",
		"placeholder_base_url": "http://localhost:20128/v1 or https://openrouter.ai/api/v1",
		"mode_manual": "Manual",
		"mode_auto": "Auto",
		"mode_full_auto": "Full Auto",
		"tooltip_approve_mode": "Approval Mode (Manual / Auto / Full Auto)",
		"label_auto_approve_mode": "Auto Approve Mode:",
		"label_provider_type": "AI Provider Mode:",
		"provider_antigravity": "Google Antigravity CLI (Official, Local, Direct Session)",
		"provider_openai": "OpenAI-Compatible (9Router, Ollama, OpenRouter, LM Studio)",
		"hint_temp_ideal": "Default for coding and logical precision: 0.20.",
		"btn_reset_temp": "0.20 (Default)",
		"tab_provider": "Provider",
		"tab_parameters": "Model & Parameters",
		"tab_appearance": "Appearance & Language",
		"tab_system_prompt": "System Prompt",
		"label_language": "Interface Language:",
		"btn_reset_prompt": "Restore Default Prompt",
		"hint_prompt_reset": "Restores the default file-first surgical editing system prompt.",
		"history_title": "Chat History",
		"history_search_placeholder": "Search past chats...",
		"history_empty": "No past conversations found.",
		"history_not_found": "No matching conversations found.",
		"history_rename_title": "Rename Chat",
		"history_rename_prompt": "Enter new chat title:",
		"history_delete_title": "Delete Chat",
		"history_delete_prompt": "Are you sure you want to permanently delete this chat?",
		"history_btn_new": "+ New Chat",
		"history_btn_close_tooltip": "Close and Return to Chat",
		"history_tooltip_rename": "Rename",
		"history_tooltip_delete": "Delete"
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
