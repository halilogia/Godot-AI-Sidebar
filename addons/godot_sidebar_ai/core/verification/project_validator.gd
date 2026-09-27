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
