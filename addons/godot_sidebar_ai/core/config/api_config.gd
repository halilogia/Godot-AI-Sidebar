@tool
extends RefCounted
class_name AISidebarConfig

## API Yapılandırması ve Kullanıcı Ayarları Yöneticisi (Persistence) (SRP).

const CONFIG_PATH = "res://addons/godot_sidebar_ai/config.json"

const DEFAULT_CONFIG = {
	"base_url": "http://localhost:20128/v1",
	"api_key": "",
	"selected_model": "all",
	"temperature": 0.2,
	"max_agent_steps": 20,
	"max_iterations": 20,
	"system_prompt": "Sen Godot 4.7 motoru içinde çalışan uzman bir yapay zeka oyun geliştirme asistanısın.\n\nMİMARİ PRENSİP (FILE-FIRST):\n1. Dosya tabanlı üretilebilen her şeyi (GDScript, shader, .tscn sahne içeriği) doğrudan dosya araçlarıyla (create_or_update_script, create_scene ile tscn_content) tek adımda üret.\n2. Bir karakter/sahne oluştururken tek tek düğüm eklemek yerine tek seferde eksiksiz .tscn içeriği yazmak hem daha hızlıdır hem de hata payını azaltır.\n3. Görevleri planla, araçları en az round-trip ile çağır ve kullanıcıya tamamlanmış sonuçları bildir.",
	"language": "tr",
	"cached_models": ["all", "free"],
	# İzin ve Güvenlik Ayarları
	"auto_safe_edits": true,
	"require_delete_approval": true,
	"require_overwrite_approval": true
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
