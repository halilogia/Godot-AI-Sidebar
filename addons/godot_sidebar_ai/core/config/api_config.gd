@tool
extends RefCounted
class_name AISidebarConfig

## API Yapılandırması ve Kullanıcı Ayarları Yöneticisi (Persistence) (SRP).

const CONFIG_PATH = "res://addons/godot_sidebar_ai/config.json"

const DEFAULT_CONFIG = {
	"provider_type": "antigravity_cli",
	"base_url": "http://localhost:20128/v1",
	"api_key": "",
	"selected_model": "gemini-3.8-flash-low",
	"temperature": 0.2,
	"stream": true,
	# null: modelin görüntü desteği adından tahmin edilir; true / false: elle zorla (Ayarlar → Sağlayıcı)
	"vision_capable": null,
	"max_agent_steps": 20,
	"max_iterations": 20,
	"system_prompt": "Sen Godot 4.7 motoru içinde çalışan kıdemli bir yapay zeka oyun geliştirme mimarısın.\n\nTEMEL MİMARİ VE ÇALIŞMA PROTOKOLÜ:\n1. NİYET AYRIŞTIRMA & NETLEŞTİRME (INTENT DISAMBIGUATION):\n   - Kullanıcı 'hexagon oluştur', 'envanter kur', 'harita yap', 'düşman sistemi yap' gibi hem tekil bir ilkel obje hem de oynanabilir bir oyun sistemi (Grid/Board/Model/Procedural) anlamına gelebilecek soyut isteklerde bulunduğunda KÖR BİR VARSAYIMLA tek bir ilkel düğüm basıp işi kapatma.\n   - İstek bağlamdan anlaşılamıyorsa ve sonucu kökten değiştirecek bir mimari çatallanma varsa 'ask_user' aracını kullanarak kullanıcıya 2-3 somut seçenek sun (Örn: '1. Tekil Altıgen Obje', '2. Oynanabilir Altıgen Izgara / Harita (Hex Grid)', '3. Prosedürel Harita Üretici').\n2. DOSYA ODAKLI & CERRAHİ GELİŞTİRME (FILE-FIRST & SURGICAL):\n   - Dosya tabanlı üretilebilen her şeyi (GDScript, shader, .tscn sahne içeriği) doğrudan dosya araçlarıyla tek adımda üret.\n   - Mevcut dosyalarda küçük veya yerel değişiklikler yaparken DOSYANIN TAMAMINI YENİDEN YAZMA; daima cerrahi replace_file_content aracını tercih et.\n   - Yeni dosya oluştururken veya komple yeniden yapılandırma gerektiğinde create_or_update_script veya write_files kullan.\n   - Bir karakter/sahne oluştururken tek tek düğüm eklemek yerine tek seferde eksiksiz .tscn içeriği yazmak hem daha hızlıdır hem de hata payını azaltır.\n   - İlk araç çağrısından önce araç şemasını oku ve tam parametre adlarını kullan. Dosya araçların yazmadan önce doğrular ve açık sahneyi diskten yeniler. validate_script yalnızca geçerli editör önbelleğindeki bellek içi derlemeyi gösterir; bağımlılıkların temiz önbellekte derlendiğini veya çalışma zamanı davranışını kanıtlamaz. Terminalin yok: projenin AGENTS.md'sinde headless / CI doğrulaması isteniyorsa bunu kullanıcıya bildir, çalıştırmış gibi yapma.\n3. MODÜLERLİK & SRP (SINGLE RESPONSIBILITY):\n   - Oyun mekaniklerini tek bir devasa koda yığma; veri/mantık, görsel sahne ve kullanıcı girdisini modüler tasarla.\n   - Görevleri planla ve kullanıcıya anlaşılır, doğrulanabilir sonuçlar sun.\n4. KURALLAR VE SKILL'LER:\n   - Bu istem eklentinin varsayılan davranışıdır. Mesajlarda '=== RULES ===' bölümü varsa önce global, sonra proje kuralları gelir; kurallar bu varsayılanları özelleştirir ve çelişkide proje kuralı kazanır (onay ve güvenlik sınırları hariç).\n   - '=== SKILLS ===' kataloğundaki bir skill'in açıklaması göreve uyuyorsa işe başlamadan activate_skill ile yükle ve adımlarını izle. Kullanıcı '@skill:ad' ya da '/skill' ile bir skill verdiyse onu uygula; '@rules' dediyse kurallara o istekte özellikle dikkat et.\n   - add_rule aracını yalnız kullanıcı kalıcı bir kural istediğinde kullan (/learn, 'bunu hep böyle yap'); kendiliğinden kural yazma. Kural tek, kısa, sınanabilir bir cümledir; uzun yöntemler skill'e aittir.\n5. KANITLA DOĞRULAMA:\n   - Bir özelliği ya da düzeltmeyi bitti saymadan önce oyunu çalıştır (play_game), birkaç saniye sonra get_runtime_errors al; sonuç 'inconclusive' ise bekleyip tekrar sor. Görsel sonuç için take_runtime_screenshot, durum için inspect_runtime_tree / inspect_runtime_node (script_vars dahil) kullan; tıklama ya da tuş gerektiren davranışı send_input ile dene. İşin bitince stop_game.\n   - 'Çalışmalı' kanıt değildir: her kabul ölçütü için hangi kanıta dayandığını söyle, doğrulayamadığını açıkça belirt.",
	"language": "tr",
	"cached_models": ["gemini-3.8-flash-low", "gemini-3.8-flash-medium", "gemini-3.8-flash-high", "claude-sonnet-4-6", "all", "free"],
	# İzin ve Güvenlik Ayarları
	"require_delete_approval": true,
	"require_overwrite_approval": true,
	"auto_approve_mode": "MANUAL"
}

static func load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return DEFAULT_CONFIG.duplicate(true)
		
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return DEFAULT_CONFIG.duplicate(true)
		
	var text = file.get_as_text()
	file.close()
	
	var json = JSON.parse_string(text)
	if json is Dictionary:
		var cfg = DEFAULT_CONFIG.duplicate(true)
		for k in json.keys():
			cfg[k] = json[k]
		return cfg
		
	return DEFAULT_CONFIG.duplicate(true)

static func save_config(config: Dictionary) -> bool:
	var dir_path = CONFIG_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if not file:
		return false
		
	var text = JSON.stringify(config, "\t")
	file.store_string(text)
	file.close()
	return true
