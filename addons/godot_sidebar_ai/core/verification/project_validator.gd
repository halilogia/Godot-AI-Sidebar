@tool
extends RefCounted
class_name AISidebarProjectValidator

## Proje doğrulaması (`validate_project`): projedeki her GDScript gerçek yolu ve gerçek proje bağlamıyla
## (class_name'ler, preload'lar, tipler) derlenir; sahne ve kaynakların bağımlılıkları var mı bakılır.
## Her hata için dosya, satır, mesaj. Betik ResourceLoader.CACHE_MODE_IGNORE ile yüklenir: editörün
## önbelleğindeki betik değişmez, çalışan araçlar etkilenmez. Godot derleme hatalarını yalnız loga yazdığı
## için bir Logger ile yakalanır (Godot 4.5+). Betik çalıştırılmaz; çalışma zamanı davranışını kanıtlamaz.

const SELF_ADDON := "res://addons/godot_sidebar_ai/"
const MAX_ERRORS := 100
const RESOURCE_EXTS: Array[String] = ["tscn", "tres", "scn", "res"]

## Derleme hatalarını dosya / satır / mesaj olarak toplar (Logger çağrıları başka iş parçacığından gelebilir).
class _ErrorCapture extends Logger:
	var items: Array[Dictionary] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if function != "GDScript::reload":
			return
		var msg := rationale if not rationale.is_empty() else code
		_mutex.lock()
		items.append({"file": file, "line": line, "message": msg.trim_prefix("Parse Error: ")})
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

## Betiği derler ve Godot'nun loga yazdığı derleme hatalarını satır / mesaj olarak döndürür (tek dosya
## doğrulamasında "Derleme kodu: 43" yerine gerçek hata). Dönüş: {"code": Error, "errors": [{line, message}]}.
static func compile_with_errors(script: GDScript) -> Dictionary:
	var capture := _ErrorCapture.new()
	OS.add_logger(capture)
	var code := script.reload()
	OS.remove_logger(capture)
	var errors: Array[Dictionary] = []
	for e: Dictionary in capture.items:
		errors.append({"line": e["line"], "message": e["message"]})
	return {"code": code, "errors": errors}

## Hata listesini modelin okuyacağı kısa metne çevirir: "line 12: Identifier "x" not declared …".
static func format_errors(errors: Array, max_items: int = 5) -> String:
	var parts := PackedStringArray()
	var seen := {}
	for e: Dictionary in errors:
		var line_no: int = e.get("line", 0)
		var line_text := "line %d: %s" % [line_no, str(e.get("message", ""))]
		if seen.has(line_text):
			continue
		seen[line_text] = true
		parts.append(line_text)
		if parts.size() >= max_items:
			break
	return "; ".join(parts)

## `root` altındaki projeyi doğrular (varsayılan bütün proje; eklentinin kendi klasörü atlanır).
static func run(root: String = "res://") -> Dictionary:
	var started := Time.get_ticks_msec()
	var scripts: Array[String] = []
	var resources: Array[String] = []
	_collect(root, scripts, resources)

	var capture := _ErrorCapture.new()
	OS.add_logger(capture)
	for path: String in scripts:
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	OS.remove_logger(capture)

	var errors: Array[Dictionary] = []
	var seen := {}
	for e: Dictionary in capture.items:
		var key := "%s:%d:%s" % [e["file"], e["line"], e["message"]]
		if not seen.has(key):
			seen[key] = true
			errors.append({"kind": "script", "file": e["file"], "line": e["line"], "message": e["message"]})
	for path: String in resources:
		for dep: String in ResourceLoader.get_dependencies(path):
			var target := _dependency_path(dep)
			if not target.is_empty() and not ResourceLoader.exists(target):
				errors.append({"kind": "dependency", "file": path, "line": 0, "message": "Missing dependency: " + target})

	# Proje ayarları yalnız tüm projede denetlenir: kırık autoload / ana sahne kaydı Godot'nun Output'unda
	# "Failed to create an autoload" olarak görünür ve oyun açılmaz (görev geri alınınca dosya silinir, kayıt kalır).
	if root == "res://":
		var settings := {}
		for prop: Dictionary in ProjectSettings.get_property_list():
			var pname := str(prop.get("name", ""))
			if pname.begins_with("autoload/") or pname == "application/run/main_scene":
				settings[pname] = str(ProjectSettings.get_setting(pname, ""))
		errors.append_array(setting_errors(settings))

	var total := errors.size()
	return {
		"scope": "project" if root == "res://" else root,
		"engine": str(Engine.get_version_info().get("string", "")),
		"duration_ms": Time.get_ticks_msec() - started,
		"scripts_checked": scripts.size(),
		"resources_checked": resources.size(),
		"error_count": total,
		"errors": errors.slice(0, MAX_ERRORS),
		"truncated": total > MAX_ERRORS,
		"validation_scope": "project_compilation_and_dependencies",
		"runtime_verified": false,
	}

## Proje ayarlarındaki kırık yollar: {ayar adı: değer} → hata listesi. Autoload değeri "*res://yol" biçimindedir
## ("*" tekil düğüm bayrağı); uid:// ya da yolu olmayan değerler ResourceLoader ile sınanır.
static func setting_errors(settings: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: Variant in settings.keys():
		var name := str(key)
		var target := str(settings[key]).trim_prefix("*").strip_edges()
		if target.is_empty() or not (target.begins_with("res://") or target.begins_with("uid://")):
			continue
		if ResourceLoader.exists(target):
			continue
		var what := "Autoload '%s'" % name.trim_prefix("autoload/") if name.begins_with("autoload/") else "Main scene"
		out.append({"kind": "project_setting", "file": "project.godot", "line": 0,
			"message": "%s points to a missing file: %s (remove the entry with manage_project_settings remove_autoload / set, or write the file)" % [what, target]})
	return out

## get_dependencies girdisi ("uid://…::Tür::res://yol" ya da "res://yol::Tür") içindeki yol.
static func _dependency_path(dep: String) -> String:
	for part: String in dep.split("::"):
		if part.begins_with("res://"):
			return part
	var first := dep.get_slice("::", 0)
	return first if first.begins_with("uid://") else ""

static func _collect(dir: String, scripts: Array[String], resources: Array[String]) -> void:
	if dir.begins_with(SELF_ADDON) or (dir + "/").begins_with(SELF_ADDON):
		return
	var da := DirAccess.open(dir)
	if da == null:
		return
	for f: String in da.get_files():
		var path := dir.path_join(f)
		var ext := f.get_extension().to_lower()
		if ext == "gd":
			scripts.append(path)
		elif ext in RESOURCE_EXTS:
			resources.append(path)
	for d: String in da.get_directories():
		# Gizli klasörler (.godot, .git …) ve Godot'nun da atladığı .gdignore'lu klasörler taranmaz.
		if not d.begins_with(".") and not FileAccess.file_exists(dir.path_join(d).path_join(".gdignore")):
			_collect(dir.path_join(d), scripts, resources)
