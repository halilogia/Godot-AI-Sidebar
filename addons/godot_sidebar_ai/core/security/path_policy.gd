@tool
extends RefCounted
class_name AISidebarPathPolicy

## Dosya ve Yol Güvenlik Politikası (Path Security & Permission Policy) (SRP).
## Path traversal (../) saldırılarını engeller ve korumalı dosyaları (blacklist) muhafaza eder.

const PROTECTED_PREFIXES: Array[String] = [
	"res://.git/",
	"res://addons/godot_sidebar_ai/",
	"res://.godot/",
	"res://.import/"
]

const PROTECTED_EXACT_FILES: Array[String] = [
	"res://project.godot",
	"res://export_presets.cfg"
]

static func normalize_path(raw_path: String) -> String:
	var path = raw_path.strip_edges().replace("\\", "/")
	if not path.begins_with("res://") and not path.begins_with("user://"):
		path = "res://" + path.trim_prefix("/")
		
	# Path Traversal (..) Temizliği
	var prefix = "res://" if path.begins_with("res://") else "user://"
	var relative = path.trim_prefix(prefix)
	var segments = relative.split("/")
	var clean_segments: Array[String] = []
	
	for s in segments:
		if s == "" or s == ".":
			continue
		elif s == "..":
			if clean_segments.size() > 0:
				clean_segments.pop_back()
		else:
			clean_segments.append(s)
			
	return prefix + "/".join(clean_segments)

static func is_safe_to_read(raw_path: String) -> Dictionary:
	var norm = normalize_path(raw_path)
	if norm.begins_with("res://.git/"):
		return {"safe": false, "reason": "Git iç dizinine erişim yasaktır."}
	return {"safe": true, "path": norm}

static func is_safe_to_write(raw_path: String) -> Dictionary:
	var norm = normalize_path(raw_path)
	
	for exact in PROTECTED_EXACT_FILES:
		if norm == exact:
			return {
				"safe": false,
				"reason": "Kritik proje yapılandırma dosyası (" + exact + ") doğrudan yazılamaz/ezilemez."
			}
			
	for prefix in PROTECTED_PREFIXES:
		if norm.begins_with(prefix):
			return {
				"safe": false,
				"reason": "Korumalı eklenti veya sistem klasörüne (" + prefix + ") yazma izni yoktur."
			}
			
	return {"safe": true, "path": norm}

static func is_safe_to_delete(raw_path: String) -> Dictionary:
	var norm = normalize_path(raw_path)
	if norm == "res://" or norm == "res://scenes" or norm == "res://scripts":
		return {"safe": false, "reason": "Kök dizinler veya ana klasörler silinemez."}
	return is_safe_to_write(norm)
