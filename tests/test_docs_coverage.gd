@tool
extends RefCounted

## Doküman kapsamı: eklentideki her .gd dosyası ARCHITECTURE.md'de adıyla geçmelidir.
## Yeni dosya eklenip mimari belgesine yazılmazsa bu test kırmızıya döner (AGENTS.md §10).

const ROOT = "res://addons/godot_sidebar_ai"
const DOC = "res://ARCHITECTURE.md"

static func _collect(path: String, out: Array) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(path.path_join(f))
	for d in dir.get_directories():
		_collect(path.path_join(d), out)

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []

	var doc = FileAccess.get_file_as_string(DOC)
	var files: Array = []
	_collect(ROOT, files)
	var missing: Array = []
	for f in files:
		var stem = str(f).get_file().get_basename()
		var re = RegEx.create_from_string("(?<![A-Za-z0-9_])" + stem + "(?![A-Za-z0-9_])")
		if re.search(doc) == null:
			missing.append(str(f).trim_prefix(ROOT + "/"))
	if not doc.is_empty() and files.size() > 20 and missing.is_empty():
		passed += 1
	else:
		failed += 1
		errors.append("ARCHITECTURE.md'de geçmeyen dosyalar (%d/%d): %s" % [missing.size(), files.size(), str(missing)])

	return {"name": "DocsCoverageTests", "passed": passed, "failed": failed, "errors": errors}
