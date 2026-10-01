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
##   - Sağlayıcı profilleri KULLANICI düzeyindedir: liste (ad, adres, anahtar, model listesi) editörün kullanıcı
##     klasöründeki tek dosyada (providers.json) durur, bütün projeler aynı listeyi görür; projede yalnız hangi
##     profilin etkin olduğu ve düz anahtarlar (etkin profilin değerleri) kalır. Depo yalnız normal editör
##     oturumunda açılır (plugin.gd); testler, benchmark ve duman testi kullanıcının dosyasına dokunmaz.
##   - Sağlayıcı profilleri (provider_profiles, active_provider_id): birden çok sağlayıcı (9Router, OpenRouter,
##     Ollama …) yan yana saklanır. Etkin profilin değerleri düz anahtarlarda da durur (base_url, api_key,
##     selected_model …); kod bunları okur, save_config düz anahtarları etkin profile geri yazar.
##   Sıfırlamak için config.json ve config.json.bak birlikte silinir.

const CONFIG_PATH = "res://addons/godot_sidebar_ai/config.json"
const BACKUP_PATH = "res://addons/godot_sidebar_ai/config.json.bak"
const CORRUPT_PATH = "res://addons/godot_sidebar_ai/config.json.corrupt"
const TEMP_PATH = "res://addons/godot_sidebar_ai/config.json.tmp"
## Ayar dosyası biçiminin sürümü; biçim değişince artırılır ve migrate() adımı eklenir.
const CONFIG_VERSION := 3
## Kimliği belirleyen alanlar (hangi sağlayıcı): yalnız Ayarlar'daki profil formu değiştirir. Düz anahtarlardan
## profile geri yazılmaz; etkin kimlik ile düz anahtarlar bir an uyuşmasa bile (iki oturum, eski proje kopyası)
## bir profilin adresine / anahtarına başka sağlayıcınınki yazılamaz.
const IDENTITY_KEYS: Array[String] = ["provider_type", "base_url", "api_key"]
## Profile ait ayarlar: sağlayıcı değişince bunlar da değişir (model seçimi dahil).
const PROFILE_KEYS: Array[String] = ["provider_type", "base_url", "api_key", "selected_model", "cached_models",
	"stream", "report_usage", "context_window", "vision_capable", "reasoning_effort"]

## Kullanıcı düzeyi sağlayıcı deposu (bkz. sınıf başlığı). Yalnız plugin.gd normal oturumda açar.
static var global_store_enabled: bool = false
## Testler için klasör; boşsa <ayar klasörü>/Godot/godot_ai_sidebar.
static var global_store_dir_override: String = ""

static func global_store_path() -> String:
	var dir := global_store_dir_override
	if dir.is_empty():
		dir = OS.get_config_dir().path_join("Godot").path_join("godot_ai_sidebar")
	return dir.path_join("providers.json")

## Küresel dosyadaki profiller; dosya yoksa ya da bozuksa null.
static func _read_global_profiles() -> Variant:
	var d: Variant = _read_json(global_store_path())
	if d == null:
		return null
	var dict: Dictionary = d
	var list_v: Variant = dict.get("provider_profiles", null)
	return list_v if list_v is Array else null

static func _write_global_profiles(profiles_list: Array) -> void:
	var path := global_store_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"provider_profiles": profiles_list}, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)

## Projenin (eski) profilleri küresel depoya katılır (kimliğe göre birleşim), liste küresel olandan gelir.
## Etkin profil listede yoksa ilki etkin olur. Depo kapalıysa dokunmaz.
static func _with_global_profiles(cfg: Dictionary) -> Dictionary:
	if not global_store_enabled:
		return cfg
	var project_list: Array = []
	for prof: Dictionary in profiles(cfg):
		project_list.append(prof.duplicate(true))
	var stored: Variant = _read_global_profiles()
	var merged: Array = []
	if stored is Array:
		var stored_list: Array = stored
		merged = stored_list.duplicate(true)
		var added := false
		for p: Dictionary in project_list:
			var same := false
			var id_taken := false
			for m: Variant in merged:
				var md: Dictionary = m
				var same_url := str(md.get("base_url", "")) == str(p.get("base_url", ""))
				if same_url and (str(md.get("id", "")) == str(p.get("id", "")) or str(md.get("api_key", "")) == str(p.get("api_key", ""))):
					same = true
				if str(md.get("id", "")) == str(p.get("id", "")):
					id_taken = true
			if same:
				continue
			if id_taken:
				# Aynı kimlik başka bir sağlayıcıya ait (iki proje de "default" üretmiş): yeni kimlik verilir.
				var old_id := str(p.get("id", ""))
				var new_id := "p%d" % Time.get_ticks_usec()
				p["id"] = new_id
				if str(cfg.get("active_provider_id", "")) == old_id:
					cfg["active_provider_id"] = new_id
			merged.append(p)
			added = true
		if added:
			_write_global_profiles(merged)
	else:
		merged = project_list
		if not merged.is_empty():
			_write_global_profiles(merged)
	if merged.is_empty():
		return cfg
	cfg["provider_profiles"] = merged
	# Etkin profilin değerleri düz anahtarlara PROFİLDEN gelir (kaynak profil): projenin eski / bayat düz
	# anahtarları başka bir sağlayıcıyı gösterse de ekran ve istekler etkin profile uyar.
	var active_id := str(cfg.get("active_provider_id", ""))
	if not apply_profile(cfg, active_id):
		var first: Dictionary = merged[0]
		apply_profile(cfg, str(first.get("id", "")))
	return cfg

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
	# Düşünen modellerde akıl yürütme çabası: "" (Otomatik: istekte gönderilmez), "low", "medium", "high".
	# Düşük, yavaş düşünen modelleri (dakikalarca düşünme) belirgin hızlandırır; uç nokta reddederse Otomatik'e dön.
	"reasoning_effort": "",
	# null: modelin görüntü desteği adından tahmin edilir; true / false: elle zorla (Ayarlar → Sağlayıcı)
	"vision_capable": null,
	"system_prompt": "Godot 4.7 editörünün içinde çalışıyorsun.\n\nÇALIŞMA PROTOKOLÜ:\n1. ÖNCE VARSAY, SONRA SÖYLE:\n   - İstek makul biçimde yorumlanabiliyorsa soru sorma: kullanıcının kelimelerine en yakın yorumu seç, büyük isteklerde önce en küçük çalışan sürümü yap, varsayımını tek cümleyle söyle ve başla. Kullanıcı gerekirse düzeltir.\n   - 'ask_user' yalnız iki yorum birbirini dışlayan ve geri dönüşü pahalı işler doğuruyorsa ve istekte hiçbir ipucu yoksa kullanılır. Kullanıcı neyi istediğini yazmışsa (ör. 'arayüz'), kapsam ya da parametrik detaylar (hız, renk, boyut) için sorma.\n2. DOSYA ODAKLI & CERRAHİ GELİŞTİRME (FILE-FIRST & SURGICAL):\n   - Dosya tabanlı üretilebilen her şeyi (GDScript, shader, .tscn sahne içeriği) doğrudan dosya araçlarıyla tek adımda üret.\n   - Mevcut dosyalarda küçük veya yerel değişiklikler yaparken DOSYANIN TAMAMINI YENİDEN YAZMA; daima cerrahi replace_file_content aracını tercih et.\n   - Yeni dosya oluştururken veya komple yeniden yapılandırma gerektiğinde create_or_update_script veya write_files kullan.\n   - Bir karakter/sahne oluştururken tek tek düğüm eklemek yerine tek seferde eksiksiz .tscn içeriği yazmak hem daha hızlıdır hem de hata payını azaltır.\n   - İlk araç çağrısından önce araç şemasını oku ve tam parametre adlarını kullan. Dosya araçların yazmadan önce doğrular ve açık sahneyi diskten yeniler. validate_script tek dosyayı hızlı denetler; birden çok script değiştirdiysen ya da projenin derlendiğini söyleyeceksen validate_project çalıştır: bütün script'leri gerçek proje bağlamında derler, sahne / kaynak bağımlılıklarını denetler ve her hatayı dosya, satır ve mesajla verir. İkisi de çalışma zamanı davranışını kanıtlamaz.\n   - API uydurma: Godot 4'te adı değişmiş olabilecek belirli bir üyeden gerçekten şüphen varsa (ör. TileMapLayer, Parallax2D) get_godot_class_info ile yalnız ona filter vererek bak. Yaygın sınıfları (CharacterBody2D, Area2D, Camera2D) kod yazmadan önce tarama; yanlış üyeyi doğrulama zaten satırıyla bildirir. Terminalin yok: projenin AGENTS.md'sinde headless / CI doğrulaması isteniyorsa bunu kullanıcıya bildir, çalıştırmış gibi yapma.\n3. KURALLAR VE SKILL'LER:\n   - Bu istem eklentinin varsayılan davranışıdır. Mesajlarda '=== RULES ===' bölümü varsa önce global, sonra proje kuralları gelir; kurallar bu varsayılanları özelleştirir ve çelişkide proje kuralı kazanır (onay ve güvenlik sınırları hariç).\n   - '=== SKILLS ===' kataloğundaki bir skill'in açıklaması göreve uyuyorsa işe başlamadan activate_skill ile yükle ve adımlarını izle. Oyuncunun göreceği her iş için (yeni oyun, sahne, seviye, arayüz) godot-visual-polish skill'ini de yükle: işe başlamadan paleti seç ve sanat yönü kuralını yaz, oyun çalışınca tek cila turu yap. Kullanıcı '@skill:ad' ya da '/skill' ile bir skill verdiyse onu uygula; '@rules' dediyse kurallara o istekte özellikle dikkat et.\n   - add_rule aracını yalnız kullanıcı kalıcı bir kural istediğinde kullan (/learn, 'bunu hep böyle yap'); kendiliğinden kural yazma. Kural tek, kısa, sınanabilir bir cümledir; uzun yöntemler skill'e aittir.\n4. KANITLA DOĞRULAMA:\n   - Bir özelliği ya da düzeltmeyi bitti saymadan önce oyunu çalıştır (play_game), birkaç saniye sonra get_runtime_errors al; sonuç 'inconclusive' ise bekleyip tekrar sor. Görsel sonuç için take_runtime_screenshot, durum için inspect_runtime_tree / inspect_runtime_node (script_vars dahil) kullan; tıklama ya da tuş gerektiren davranışı send_input ile dene. İşin bitince stop_game.\n   - 'Çalışmalı' kanıt değildir: her kabul ölçütü için hangi kanıta dayandığını söyle, doğrulayamadığını açıkça belirt.\n5. BİTİRME DİSİPLİNİ:\n   - İstenen çekirdek oyun çalışıp bir kez oynanarak doğrulandığında dur ve özetle. İstenmemiş özellik (bitiş ekranı, yeni seviye, ekstra mod) ekleme; eklemek istediğin şeyi öneri olarak yaz.\n   - Bitirmeden önce tek bir son bakış: audit_runtime_ui aracını bir kez çağır (ekran dışı, taşan, üst üste binen ya da kontrastsız metni ölçer) ve listelediğini düzelt; ayrıca son ekran görüntüsünde üst üste binen ya da kontrastsız yazı, oyun durumuyla uyuşmayan eski metin (ör. tur oynandıktan sonra hâlâ 'Kartını seç'), taşan öğe var mı? Varsa düzelt.\n   - Aynı sorunu üç kez uğraştıysan ya da bir davranışı girdiyle doğrulayamıyorsan bırak: kalanı 'doğrulanamadı' diye raporla, körlemesine test döngüsüne girme.",
	"language": "tr",
	"ui_animations": true,
	# Blender Copilot köprüsü (Ayarlar → Blender): 3B model / prop / karakter Blender'da yapılır, .glb olarak gelir.
	"blender_bridge_enabled": false,
	"blender_bridge_url": "http://127.0.0.1:6592/mcp",
	"blender_bridge_token": "",
	# Editör arka plandayken soru / onay / görev bitişinde görev çubuğu uyarısı (Ayarlar → Genel).
	"notifications": true,
	"notification_sound": false,
	"goal_max_rounds": 10,
	# Her istekte önce plan (Ayarlar → Genel); kapalıyken plan yalnız /plan ile.
	"planning_mode": false,
	"cached_models": ["all", "free"],
	# İzin ve Güvenlik Ayarları
	"require_delete_approval": true,
	"require_overwrite_approval": true,
	"auto_approve_mode": "MANUAL",
	"provider_profiles": [],
	"active_provider_id": "",
	"config_version": CONFIG_VERSION
}

static func load_config() -> Dictionary:
	var data: Variant = _read_json(CONFIG_PATH)
	if data == null:
		var main_exists := FileAccess.file_exists(CONFIG_PATH)
		var backup: Variant = _read_json(BACKUP_PATH)
		if backup == null:
			return _with_global_profiles(DEFAULT_CONFIG.duplicate(true))
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
	return _with_global_profiles(migrate(cfg))

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
	if version < 3 or profiles(cfg).is_empty():
		# v2 → v3: tek sağlayıcı ayarı ilk profil olur (mevcut 9Router ayarı kaybolmaz).
		var first := profile_from(cfg)
		first["id"] = "default"
		first["name"] = _name_from_url(str(cfg.get("base_url", "")))
		cfg["provider_profiles"] = [first]
		cfg["active_provider_id"] = "default"
	cfg["config_version"] = CONFIG_VERSION
	return cfg

## Kayıtlı sağlayıcı profilleri (sözlük olmayan girdiler atlanır; sözlükler yerinde, kopya değil).
static func profiles(cfg: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list_v: Variant = cfg.get("provider_profiles", [])
	if list_v is Array:
		var list: Array = list_v
		for prof_v: Variant in list:
			if prof_v is Dictionary:
				var prof: Dictionary = prof_v
				out.append(prof)
	return out

## Düz anahtarlardaki (etkin) sağlayıcı ayarları, profil biçiminde.
static func profile_from(cfg: Dictionary) -> Dictionary:
	var p: Dictionary = {}
	for k: String in PROFILE_KEYS:
		p[k] = _copy(cfg.get(k, DEFAULT_CONFIG.get(k)))
	return p

## Etkin profil (yoksa boş sözlük; sözlük yerindedir).
static func active_profile(cfg: Dictionary) -> Dictionary:
	var id := str(cfg.get("active_provider_id", ""))
	for prof: Dictionary in profiles(cfg):
		if str(prof.get("id", "")) == id:
			return prof
	return {}

## Düz anahtarları etkin profile yazar (model seçimi, model listesi gibi değişiklikler profilde kalsın).
static func sync_active_profile(cfg: Dictionary) -> void:
	var prof := active_profile(cfg)
	if prof.is_empty():
		return
	var live := profile_from(cfg)
	for k: String in IDENTITY_KEYS:
		live.erase(k)
	prof.merge(live, true)

## Profilin değerlerini düz anahtarlara kopyalar (geri yazma yapmaz). Etkin profil kimliğini ayarlar.
static func apply_profile(cfg: Dictionary, id: String) -> bool:
	for prof: Dictionary in profiles(cfg):
		if str(prof.get("id", "")) == id:
			for k: String in PROFILE_KEYS:
				if prof.has(k):
					cfg[k] = _copy(prof[k])
			cfg["active_provider_id"] = id
			return true
	return false

## Başka profile geçer: önce etkin profil güncellenir, sonra hedefin değerleri düz anahtarlara kopyalanır.
static func activate_profile(cfg: Dictionary, id: String) -> bool:
	sync_active_profile(cfg)
	return apply_profile(cfg, id)

static func _copy(v: Variant) -> Variant:
	if v is Array:
		var arr: Array = v
		return arr.duplicate()
	return v

## Adresten okunur profil adı (ör. "openrouter.ai", "localhost:20128").
static func _name_from_url(url: String) -> String:
	var host := url.trim_prefix("https://").trim_prefix("http://").get_slice("/", 0)
	return host if not host.is_empty() else "Provider"

static func save_config(config: Dictionary) -> bool:
	var dir_path := CONFIG_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	config["config_version"] = CONFIG_VERSION
	sync_active_profile(config)
	var to_write: Dictionary = config
	if global_store_enabled:
		# Liste kullanıcı düzeyinde durur; proje dosyasında anahtarlar / adresler kopyalanmaz (silinen profil
		# başka projenin eski kopyasından geri gelmesin).
		var plist: Array = config.get("provider_profiles", [])
		_write_global_profiles(plist)
		to_write = config.duplicate(true)
		to_write.erase("provider_profiles")
	# Son sağlam dosya yedeklenir; bozuk dosya yedeği ezmez.
	if _read_json(CONFIG_PATH) != null:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(CONFIG_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	var tmp := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if not tmp:
		return false
	tmp.store_string(JSON.stringify(to_write, "\t"))
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
