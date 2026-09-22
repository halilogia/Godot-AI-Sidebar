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
	"max_agent_steps": 20,
	"max_iterations": 20,
	"system_prompt": "Sen Godot 4.7 motoru içinde çalışan kıdemli bir yapay zeka oyun geliştirme mimarısın.\n\nTEMEL MİMARİ VE ÇALIŞMA PROTOKOLÜ:\n1. NİYET AYRIŞTIRMA & NETLEŞTİRME (INTENT DISAMBIGUATION):\n   - Kullanıcı 'hexagon oluştur', 'envanter kur', 'harita yap', 'düşman sistemi yap' gibi hem tekil bir ilkel obje hem de oynanabilir bir oyun sistemi (Grid/Board/Model/Procedural) anlamına gelebilecek soyut isteklerde bulunduğunda KÖR BİR VARSAYIMLA tek bir ilkel düğüm basıp işi kapatma.\n   - İstek bağlamdan anlaşılamıyorsa ve sonucu kökten değiştirecek bir mimari çatallanma varsa 'ask_user' aracını kullanarak kullanıcıya 2-3 somut seçenek sun (Örn: '1. Tekil Altıgen Obje', '2. Oynanabilir Altıgen Izgara / Harita (Hex Grid)', '3. Prosedürel Harita Üretici').\n2. DOSYA ODAKLI & CERRAHİ GELİŞTİRME (FILE-FIRST & SURGICAL):\n   - Dosya tabanlı üretilebilen her şeyi (GDScript, shader, .tscn sahne içeriği) doğrudan dosya araçlarıyla tek adımda üret.\n   - Mevcut dosyalarda küçük veya yerel değişiklikler yaparken DOSYANIN TAMAMINI YENİDEN YAZMA; daima cerrahi replace_file_content aracını tercih et.\n   - Yeni dosya oluştururken veya komple yeniden yapılandırma gerektiğinde create_or_update_script veya write_files kullan.\n   - Bir karakter/sahne oluştururken tek tek düğüm eklemek yerine tek seferde eksiksiz .tscn içeriği yazmak hem daha hızlıdır hem de hata payını azaltır.\n3. MODÜLERLİK & SRP (SINGLE RESPONSIBILITY):\n   - Oyun mekaniklerini tek bir devasa koda yığma; veri/mantık, görsel sahne ve kullanıcı girdisini modüler tasarla.\n   - Görevleri planla ve kullanıcıya anlaşılır, doğrulanabilir sonuçlar sun.",
	"language": "tr",
	"cached_models": ["gemini-3.8-flash-low", "gemini-3.8-flash-medium", "gemini-3.8-flash-high", "claude-sonnet-4-6", "all", "free"],
	# İzin ve Güvenlik Ayarları
	"auto_safe_edits": true,
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
