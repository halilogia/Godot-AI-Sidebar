@tool
extends RefCounted

## Ayar dosyası güvenliği: yedek, bozuk / eksik dosyada yedekten geri yükleme, bozuk dosyanın yedeği
## ezmemesi, sürüm ve taşıma. Test çalıştırıcı kişisel dosyaları kenara aldığı için gerçek yollarla çalışır.

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

static func _clean() -> void:
	for p: String in [AISidebarConfig.CONFIG_PATH, AISidebarConfig.BACKUP_PATH, AISidebarConfig.CORRUPT_PATH, AISidebarConfig.TEMP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	AISidebarConfig.last_recovery = ""

static func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []
	_clean()

	# T1 Dosya yokken varsayılanlar; kurtarma yok.
	var d := AISidebarConfig.load_config()
	if str(d.get("language", "")) == "tr" and AISidebarConfig.last_recovery == "" and int(d.get("config_version", 0)) == AISidebarConfig.CONFIG_VERSION:
		passed += 1
	else:
		failed += 1
		errors.append("T1 defaults: %s / %s" % [d.get("language"), AISidebarConfig.last_recovery])

	# T2 Her kayıt öncesi son sağlam dosya yedeklenir; geçici dosya kalmaz.
	var a := AISidebarConfig.load_config()
	a["language"] = "en"
	AISidebarConfig.save_config(a)
	var b := AISidebarConfig.load_config()
	b["language"] = "tr"
	b["temperature"] = 0.7
	AISidebarConfig.save_config(b)
	var bak: Variant = JSON.parse_string(FileAccess.get_file_as_string(AISidebarConfig.BACKUP_PATH))
	var bak_ok: bool = bak is Dictionary and str((bak as Dictionary).get("language", "")) == "en"
	if bak_ok and not FileAccess.file_exists(AISidebarConfig.TEMP_PATH) and str(AISidebarConfig.load_config().get("language", "")) == "tr":
		passed += 1
	else:
		failed += 1
		errors.append("T2 backup on save: bak=%s tmp_left=%s" % [str(bak), FileAccess.file_exists(AISidebarConfig.TEMP_PATH)])

	# T3 Bozuk dosya: yedekten geri yüklenir, bozuk dosya saklanır, bildirim verilir.
	_write_raw(AISidebarConfig.CONFIG_PATH, "{ bozuk json")
	var r := AISidebarConfig.load_config()
	var restored_corrupt: bool = str(r.get("language", "")) == "en" and AISidebarConfig.last_recovery == "restored_corrupt" and FileAccess.file_exists(AISidebarConfig.CORRUPT_PATH) and JSON.parse_string(FileAccess.get_file_as_string(AISidebarConfig.CONFIG_PATH)) is Dictionary
	if restored_corrupt:
		passed += 1
	else:
		failed += 1
		errors.append("T3 corrupt: lang=%s recovery=%s" % [r.get("language"), AISidebarConfig.last_recovery])

	# T4 Eksik dosya (kaybolma olayı): yedekten geri yüklenir.
	AISidebarConfig.last_recovery = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AISidebarConfig.CONFIG_PATH))
	var m := AISidebarConfig.load_config()
	if str(m.get("language", "")) == "en" and AISidebarConfig.last_recovery == "restored_missing" and FileAccess.file_exists(AISidebarConfig.CONFIG_PATH):
		passed += 1
	else:
		failed += 1
		errors.append("T4 missing: lang=%s recovery=%s" % [m.get("language"), AISidebarConfig.last_recovery])

	# T5 Bozuk dosyanın üstüne kayıt yedeği ezmez.
	_write_raw(AISidebarConfig.CONFIG_PATH, "not json")
	var fresh := AISidebarConfig.DEFAULT_CONFIG.duplicate(true)
	AISidebarConfig.save_config(fresh)
	var bak2: Variant = JSON.parse_string(FileAccess.get_file_as_string(AISidebarConfig.BACKUP_PATH))
	if bak2 is Dictionary and str((bak2 as Dictionary).get("language", "")) == "en":
		passed += 1
	else:
		failed += 1
		errors.append("T5 corrupt file overwrote the backup: " + str(bak2))

	# T6 Taşıma: sürümsüz (v0) dosyadaki kaldırılmış ayar atılır, sürüm güncellenir.
	_clean()
	_write_raw(AISidebarConfig.CONFIG_PATH, JSON.stringify({"language": "en", "auto_safe_edits": true, "max_iterations": 7}))
	var mig := AISidebarConfig.load_config()
	if not mig.has("auto_safe_edits") and int(mig.get("config_version", 0)) == AISidebarConfig.CONFIG_VERSION and str(mig.get("language", "")) == "en":
		passed += 1
	else:
		failed += 1
		errors.append("T6 migrate: " + str(mig.keys()))

	_clean()
	return {"name": "ConfigSafetyTests", "passed": passed, "failed": failed, "errors": errors}
