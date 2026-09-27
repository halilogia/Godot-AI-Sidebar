@tool
extends RefCounted
class_name AISidebarConfig

## API Yapılandırması ve Kullanıcı Ayarları Yöneticisi (Persistence) (SRP).
##
## Ayar dosyası güvenliği:
##   - Yazma güvenli: önce geçici dosyaya yazılır, sonra yerine konur (yarım yazılmış dosya kalmaz).
##   - Her yazmadan önce son SAĞLAM dosya config.json.bak'a kopyalanır (bozuk dosya yedeği ezmez).
##   - config.json eksik ya da bozuksa yedekten geri yüklenir (bozuk dosya config.json.corrupt olarak
##     saklanır) ve last_recovery ile bildirilir; panel bunu kullanıcıya bir kez söyler.
##   - config_version ve migrate(): eski sürümün ayar dosyası yeni biçime taşınır.
##   Sıfırlamak için config.json ve config.json.bak birlikte silinir.

const CONFIG_PATH = "res://addons/godot_sidebar_ai/config.json"
const BACKUP_PATH = "res://addons/godot_sidebar_ai/config.json.bak"
const CORRUPT_PATH = "res://addons/godot_sidebar_ai/config.json.corrupt"
const TEMP_PATH = "res://addons/godot_sidebar_ai/config.json.tmp"
## Ayar dosyası biçiminin sürümü; biçim değişince artırılır ve migrate() adımı eklenir.
const CONFIG_VERSION := 2

## Son yüklemede yapılan kurtarma ("" | "restored_missing" | "restored_corrupt"); panel okur ve sıfırlar.
static var last_recovery: String = ""

const DEFAULT_CONFIG = {
	"provider_type": "openai_compatible",
	"base_url": "http://localhost:20128/v1",
	"api_key": "",
	"selected_model": "all",
	"temperature": 0.2,
	"stream": true,
	# Akışta token kullanımını iste (stream_options.include_usage); reddeden uç noktada kapatılır.
	"report_usage": true,
	# Modelin bağlam penceresi (token); 0: sağlayıcının model listesinden (bildirilmezse bilinmiyor).
	"context_window": 0,
	# null: modelin görüntü desteği adından tahmin edilir; true / false: elle zorla (Ayarlar → Sağlayıcı)
	"vision_capable": null,
	"system_prompt": "Sen Godot 4.7 motoru içinde çalışan kıdemli bir yapay zeka oyun geliştirme mimarısın.\n\nTEMEL MİMARİ VE ÇALIŞMA PROTOKOLÜ:\n1. ÖNCE VARSAY, SONRA SÖYLE:\n   - İstek makul biçimde yorumlanabiliyorsa soru sorma: kullanıcının kelimelerine en yakın yorumu seç, büyük isteklerde önce en küçük çalışan sürümü yap, varsayımını tek cümleyle söyle ve başla. Kullanıcı gerekirse düzeltir.\n   - 'ask_user' yalnız iki yorum birbirini dışlayan ve geri dönüşü pahalı işler doğuruyorsa ve istekte hiçbir ipucu yoksa kullanılır. Kullanıcı neyi istediğini yazmışsa (ör. 'arayüz'), kapsam ya da parametrik detaylar (hız, renk, boyut) için sorma.\n2. DOSYA ODAKLI & CERRAHİ GELİŞTİRME (FILE-FIRST & SURGICAL):\n   - Dosya tabanlı üretilebilen her şeyi (GDScript, shader, .tscn sahne içeriği) doğrudan dosya araçlarıyla tek adımda üret.\n   - Mevcut dosyalarda küçük veya yerel değişiklikler yaparken DOSYANIN TAMAMINI YENİDEN YAZMA; daima cerrahi replace_file_content aracını tercih et.\n   - Yeni dosya oluştururken veya komple yeniden yapılandırma gerektiğinde create_or_update_script veya write_files kullan.\n   - Bir karakter/sahne oluştururken tek tek düğüm eklemek yerine tek seferde eksiksiz .tscn içeriği yazmak hem daha hızlıdır hem de hata payını azaltır.\n   - İlk araç çağrısından önce araç şemasını oku ve tam parametre adlarını kullan. Dosya araçların yazmadan önce doğrular ve açık sahneyi diskten yeniler. validate_script tek dosyayı hızlı denetler; birden çok script değiştirdiysen ya da projenin derlendiğini söyleyeceksen validate_project çalıştır: bütün script'leri gerçek proje bağlamında derler, sahne / kaynak bağımlılıklarını denetler ve her hatayı dosya, satır ve mesajla verir. İkisi de çalışma zamanı davranışını kanıtlamaz.\n   - Bir Godot sınıfı, yöntemi, özelliği, sinyali ya da sabitinden emin değilsen API uydurma; önce get_godot_class_info ile çalışan motorun gerçek API'sine bak. Terminalin yok: projenin AGENTS.md'sinde headless / CI doğrulaması isteniyorsa bunu kullanıcıya bildir, çalıştırmış gibi yapma.\n3. MODÜLERLİK & SRP (SINGLE RESPONSIBILITY):\n   - Oyun mekaniklerini tek bir devasa koda yığma; veri/mantık, görsel sahne ve kullanıcı girdisini modüler tasarla.\n   - Görevleri planla ve kullanıcıya anlaşılır, doğrulanabilir sonuçlar sun.\n4. KURALLAR VE SKILL'LER:\n   - Bu istem eklentinin varsayılan davranışıdır. Mesajlarda '=== RULES ===' bölümü varsa önce global, sonra proje kuralları gelir; kurallar bu varsayılanları özelleştirir ve çelişkide proje kuralı kazanır (onay ve güvenlik sınırları hariç).\n   - '=== SKILLS ===' kataloğundaki bir skill'in açıklaması göreve uyuyorsa işe başlamadan activate_skill ile yükle ve adımlarını izle. Kullanıcı '@skill:ad' ya da '/skill' ile bir skill verdiyse onu uygula; '@rules' dediyse kurallara o istekte özellikle dikkat et.\n   - add_rule aracını yalnız kullanıcı kalıcı bir kural istediğinde kullan (/learn, 'bunu hep böyle yap'); kendiliğinden kural yazma. Kural tek, kısa, sınanabilir bir cümledir; uzun yöntemler skill'e aittir.\n5. KANITLA DOĞRULAMA:\n   - Bir özelliği ya da düzeltmeyi bitti saymadan önce oyunu çalıştır (play_game), birkaç saniye sonra get_runtime_errors al; sonuç 'inconclusive' ise bekleyip tekrar sor. Görsel sonuç için take_runtime_screenshot, durum için inspect_runtime_tree / inspect_runtime_node (script_vars dahil) kullan; tıklama ya da tuş gerektiren davranışı send_input ile dene. İşin bitince stop_game.\n   - 'Çalışmalı' kanıt değildir: her kabul ölçütü için hangi kanıta dayandığını söyle, doğrulayamadığını açıkça belirt.",
	"language": "tr",
	"ui_animations": true,
	"goal_max_rounds": 10,
	# Her istekte önce plan (Ayarlar → Genel); kapalıyken plan yalnız /plan ile.
	"planning_mode": false,
	"cached_models": ["all", "free"],
	# İzin ve Güvenlik Ayarları
	"require_delete_approval": true,
	"require_overwrite_approval": true,
	"auto_approve_mode": "MANUAL",
	"config_version": CONFIG_VERSION
}

static func load_config() -> Dictionary:
	var data: Variant = _read_json(CONFIG_PATH)
	if data == null:
		var main_exists := FileAccess.file_exists(CONFIG_PATH)
		var backup: Variant = _read_json(BACKUP_PATH)
		if backup == null:
			return DEFAULT_CONFIG.duplicate(true)
		# Ana dosya eksik ya da bozuk, yedek sağlam: yedekten geri yükle (bozuk dosya incelenmek üzere saklanır).
		if main_exists:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(CONFIG_PATH), ProjectSettings.globalize_path(CORRUPT_PATH))
			last_recovery = "restored_corrupt"
		else:
			last_recovery = "restored_missing"
		DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP_PATH), ProjectSettings.globalize_path(CONFIG_PATH))
		push_warning("[Godot AI] config.json %s; son yedekten (config.json.bak) geri yüklendi." % ("bozuktu" if main_exists else "eksikti"))
		data = backup
	var loaded: Dictionary = data
	var cfg: Dictionary = DEFAULT_CONFIG.duplicate(true)
	for k: Variant in loaded.keys():
		cfg[k] = loaded[k]
	if not loaded.has("config_version"):
		cfg["config_version"] = 0
	return migrate(cfg)

## Eski biçimdeki ayarları güncel biçime taşır (saf). Her biçim değişikliği bir adım ekler.
static func migrate(cfg: Dictionary) -> Dictionary:
	var version: int = cfg.get("config_version", 0)
	if version < 1:
		# v0 → v1: kaldırılan ayar.
		cfg.erase("auto_safe_edits")
	if version < 2:
		# v1 → v2: sabit adım sınırı kaldırıldı (ajan büyük işte yarıda kesilmesin).
		cfg.erase("max_agent_steps")
		cfg.erase("max_iterations")
	cfg["config_version"] = CONFIG_VERSION
	return cfg

static func save_config(config: Dictionary) -> bool:
	var dir_path := CONFIG_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	config["config_version"] = CONFIG_VERSION
	# Son sağlam dosya yedeklenir; bozuk dosya yedeği ezmez.
	if _read_json(CONFIG_PATH) != null:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(CONFIG_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	var tmp := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if not tmp:
		return false
	tmp.store_string(JSON.stringify(config, "\t"))
	tmp.close()
	var target := ProjectSettings.globalize_path(CONFIG_PATH)
	if FileAccess.file_exists(CONFIG_PATH):
		DirAccess.remove_absolute(target)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), target) == OK

## JSON sözlüğü; dosya yoksa, okunamıyorsa ya da sözlük değilse null.
static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return null
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else null
