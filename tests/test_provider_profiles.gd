@tool
extends RefCounted

## Sağlayıcı profilleri: tek sağlayıcılı eski ayar ilk profil olur (9Router ayarı kaybolmaz), profiller
## arasında geçişte her profilin kendi adresi / anahtarı / model seçimi korunur, Ayarlar sayfası profil
## ekler ve kaydederken gösterilen profili etkin yapar.

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarSettingsGeneralPages = preload("res://addons/godot_sidebar_ai/ui/components/settings_general_pages.gd")

static func _two_profiles() -> Dictionary:
	var cfg := AISidebarConfig.migrate({"config_version": 2, "base_url": "http://localhost:20128/v1", "api_key": "k9", "selected_model": "a", "cached_models": ["a", "all"]})
	var profs: Array = cfg["provider_profiles"]
	profs.append({"id": "or", "name": "OpenRouter", "provider_type": "openai_compatible", "base_url": "https://openrouter.ai/api/v1", "api_key": "kor", "selected_model": "space", "cached_models": ["space"]})
	return cfg

static func run() -> Dictionary:
	var checks: Array = []

	# P1 göç: v2 tek sağlayıcı → tek profil, etkin
	var cfg := _two_profiles()
	var first: Dictionary = (cfg["provider_profiles"] as Array)[0]
	checks.append(["P1 v2 settings become the first profile", cfg["config_version"] == AISidebarConfig.CONFIG_VERSION and cfg["active_provider_id"] == "default" and first["base_url"] == "http://localhost:20128/v1" and first["api_key"] == "k9" and first["selected_model"] == "a" and first["name"] == "localhost:20128"])

	# P2 geçiş: düz anahtarlar hedefin, eski profil son model seçimini tutar
	cfg["selected_model"] = "all"
	AISidebarConfig.activate_profile(cfg, "or")
	checks.append(["P2 switch loads target, keeps old choice", cfg["base_url"] == "https://openrouter.ai/api/v1" and cfg["api_key"] == "kor" and cfg["selected_model"] == "space" and first["selected_model"] == "all" and cfg["active_provider_id"] == "or"])

	# P3 geri dönüş
	AISidebarConfig.activate_profile(cfg, "default")
	checks.append(["P3 switch back restores own model", cfg["selected_model"] == "all" and cfg["api_key"] == "k9"])

	# P4 model listesi kopyadır (düz liste değişince profil değişmez); bilinmeyen profil reddedilir
	(cfg["cached_models"] as Array).append("x")
	checks.append(["P4 lists are copies; unknown id refused", not (first["cached_models"] as Array).has("x") and not AISidebarConfig.activate_profile(cfg, "nope")])

	# P5 Ayarlar sayfası: profil göster, ekle, kaydet → eklenen etkin
	var pages := AISidebarSettingsGeneralPages.new()
	var built: Array[Control] = [pages.build_provider_page(), pages.build_model_page(), pages.build_language_page()]
	var cfg5 := _two_profiles()
	pages.load_from(cfg5)
	var shown_default := pages.base_url_edit.text == "http://localhost:20128/v1" and pages.profile_opt.item_count == 2 and not pages.profile_delete_btn.disabled
	pages._on_profile_selected(1)
	var shown_or := pages.base_url_edit.text == "https://openrouter.ai/api/v1"
	pages._on_profile_add()
	pages.base_url_edit.text = "http://localhost:11434/v1"
	pages.profile_name_edit.text = "Ollama"
	pages.write_to(cfg5)
	var saved: Array = cfg5["provider_profiles"]
	var active := AISidebarConfig.active_profile(cfg5)
	checks.append(["P5 settings page adds a profile and activates it", shown_default and shown_or and saved.size() == 3 and cfg5["base_url"] == "http://localhost:11434/v1" and active.get("name") == "Ollama" and (saved[1] as Dictionary)["api_key"] == "kor"])

	# P7 akıl yürütme çabası profile yazılır ve geri okunur
	pages.effort_opt.selected = 1
	var eff_profile := {}
	pages._store_profile(eff_profile)
	pages.effort_opt.selected = 0
	pages._load_profile(eff_profile)
	checks.append(["P7 reasoning effort stored per profile", eff_profile.get("reasoning_effort") == "low" and pages.effort_opt.selected == 1])

	# P6 silme: son profil silinemez
	pages._on_profile_delete()
	pages._on_profile_delete()
	checks.append(["P6 last profile cannot be deleted", pages.profile_opt.item_count == 1 and pages.profile_delete_btn.disabled])
	for c: Control in built:
		c.free()

	# G: kullanıcı düzeyi (küresel) sağlayıcı deposu
	var saved_enabled := AISidebarConfig.global_store_enabled
	var saved_dir := AISidebarConfig.global_store_dir_override
	AISidebarConfig.global_store_dir_override = "user://ai_sidebar_test_global"
	var gpath := AISidebarConfig.global_store_path()
	if FileAccess.file_exists(gpath):
		DirAccess.remove_absolute(gpath)
	# G0 kapalıyken dokunmaz
	AISidebarConfig.global_store_enabled = false
	var g0 := AISidebarConfig._with_global_profiles(_two_profiles())
	checks.append(["G0 disabled store leaves config and file alone", (g0["provider_profiles"] as Array).size() == 2 and not FileAccess.file_exists(gpath)])
	AISidebarConfig.global_store_enabled = true
	# G1 ilk proje: profiller depoya tohumlanır
	var g1 := AISidebarConfig._with_global_profiles(_two_profiles())
	var stored: Variant = AISidebarConfig._read_global_profiles()
	checks.append(["G1 first project seeds the store", FileAccess.file_exists(gpath) and stored is Array and (stored as Array).size() == 2 and (g1["provider_profiles"] as Array).size() == 2])
	# G2 ikinci proje: kendi profili yok (yeni proje) -> küresel listeyi görür, etkin kimlik korunur
	var fresh := AISidebarConfig.migrate({"config_version": 2, "base_url": "http://localhost:20128/v1", "api_key": "k9", "selected_model": "a"})
	var g2 := AISidebarConfig._with_global_profiles(fresh)
	checks.append(["G2 second project sees the shared list, no duplicate for same address+key", (g2["provider_profiles"] as Array).size() == 2])
	# G3 aynı kimlik, başka sağlayıcı: ikisi de kalır, kimlik çakışması çözülür, etkin profil izlenir
	var other := AISidebarConfig.migrate({"config_version": 2, "base_url": "https://opencode.ai/zen/v1", "api_key": "ko", "selected_model": "space-bunny-free"})
	var g3 := AISidebarConfig._with_global_profiles(other)
	var ids := {}
	for prof: Dictionary in AISidebarConfig.profiles(g3):
		ids[str(prof.get("id", ""))] = true
	var active3 := AISidebarConfig.active_profile(g3)
	checks.append(["G3 same id, different provider: both kept, ids unique, active follows", (g3["provider_profiles"] as Array).size() == 3 and ids.size() == 3 and str(active3.get("base_url", "")) == "https://opencode.ai/zen/v1"])
	# G4 depo kalıcı: yeni bir "proje" hepsini görür
	var g4 := AISidebarConfig._with_global_profiles(AISidebarConfig.migrate({"config_version": 2, "base_url": "http://x.example/v1", "api_key": ""}))
	checks.append(["G4 store persists across projects", (g4["provider_profiles"] as Array).size() == 4])
	# G5 bayat düz anahtarlar başka sağlayıcıyı gösterse de etkin profil kaynaktır; otomatik eşleme adres / anahtarı bozmaz
	var stale := _two_profiles()
	stale["base_url"] = "https://opencode.ai/zen/v1"
	stale["api_key"] = "ko"
	stale["active_provider_id"] = "default"
	var g5 := AISidebarConfig._with_global_profiles(stale)
	var prof5 := AISidebarConfig.active_profile(g5)
	g5["base_url"] = "https://elsewhere.example/v1"
	g5["api_key"] = "leak"
	g5["selected_model"] = "m2"
	AISidebarConfig.sync_active_profile(g5)
	var prof5b := AISidebarConfig.active_profile(g5)
	checks.append(["G5 active profile is the source; sync never writes address/key", str(prof5.get("id")) == "default" and g5.get("selected_model") == "m2" and prof5b["base_url"] != "https://elsewhere.example/v1" and prof5b["api_key"] != "leak" and prof5b["selected_model"] == "m2"])
	if FileAccess.file_exists(gpath):
		DirAccess.remove_absolute(gpath)
	AISidebarConfig.global_store_enabled = saved_enabled
	AISidebarConfig.global_store_dir_override = saved_dir

	var passed := 0
	var errors: Array = []
	for c: Array in checks:
		if c[1]:
			passed += 1
		else:
			errors.append(str(c[0]) + " failed")
	return {"name": "ProviderProfileTests", "passed": passed, "failed": checks.size() - passed, "errors": errors}
