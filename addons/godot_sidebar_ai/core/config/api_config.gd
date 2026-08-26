@tool
extends RefCounted
class_name AISidebarConfig

const CONFIG_PATH: String = "user://godot_ai_sidebar_config.json"

static func get_default_config() -> Dictionary:
	var def_key = "sk-721f59b1b10b5139-z9w7ip-724e45e1"
	var nexus_cfg_path = "C:/Users/Halil Emre/.nexus/config.json"
	if FileAccess.file_exists(nexus_cfg_path):
		var nf = FileAccess.open(nexus_cfg_path, FileAccess.READ)
		if nf:
			var txt = nf.get_as_text()
			nf.close()
			var p = JSON.parse_string(txt)
			if p is Dictionary and p.has("apiKey") and not str(p["apiKey"]).is_empty():
				def_key = str(p["apiKey"])
				
	return {
		"base_url": "http://localhost:20128/v1",
		"api_key": def_key,
		"selected_model": "all",
		"cached_models": ["all", "free", "ag/gemini-3.7-flash-high", "ag/claude-3.7-sonnet"],
		"temperature": 0.2,
		"max_iterations": 10,
		"language": "tr",
		"system_prompt": "Sen Godot Engine 4.7 için uzman bir otonom AI oyun geliştirme asistanısın. GDScript 2.0 kodları üretir, sahne ağacını düzenler, motor araçlarını (tools) en verimli şekilde kullanır ve her zaman adım adım mantık yürüterek çalışırsın."
	}

static func load_config() -> Dictionary:
	var config = get_default_config()
	if FileAccess.file_exists(CONFIG_PATH):
		var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(content)
			if parsed is Dictionary:
				for k in parsed:
					config[k] = parsed[k]
	if str(config.get("api_key", "")).is_empty():
		config["api_key"] = get_default_config()["api_key"]
	return config

static func save_config(config: Dictionary) -> bool:
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()
		return true
	return false
