@tool
extends RefCounted
class_name AISidebarSkillRegistry

## Sidebar skill'leri (Agent Skills standardı, agentskills.io): keşif, öncelik, açık / kapalı
## tercihi, model kataloğu ve etkinleştirme içeriği. Skill'ler düz dosyadır; aynı klasörler
## standardı destekleyen başka araçlarca da (Codex, Cursor, Claude Code …) okunur.
##
## Kaynaklar ve öncelik (aynı adda üstteki kazanır):
##   project  res://.agents/skills, res://.claude/skills  — depodan gelir: kullanıcı açana kadar KAPALI
##   user     ~/.agents/skills                            — varsayılan açık
##   builtin  addons/godot_sidebar_ai/skills              — eklentiyle gelir, varsayılan açık
## Açık / kapalı tercihi kişiseldir: config.json → "skills_enabled" {ad: bool}.

const AISidebarSkillParser = preload("res://addons/godot_sidebar_ai/core/skills/skill_parser.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

const SCOPE_PROJECT := "project"
const SCOPE_USER := "user"
const SCOPE_BUILTIN := "builtin"
const BUILTIN_DIR := "res://addons/godot_sidebar_ai/skills"
const PROJECT_DIRS: Array[String] = ["res://.agents/skills", "res://.claude/skills"]
const PREFS_KEY := "skills_enabled"
const MAX_RESOURCE_BYTES := 200000
const MAX_RESOURCES_LISTED := 50

static func user_skills_dir() -> String:
	var home := OS.get_environment("USERPROFILE")
	if home.is_empty():
		home = OS.get_environment("HOME")
	if home.is_empty():
		return ""
	return home.replace("\\", "/").path_join(".agents/skills")

## Varsayılan tarama kökleri (öncelik sırasıyla).
static func default_roots() -> Array[Dictionary]:
	var roots: Array[Dictionary] = []
	for d: String in PROJECT_DIRS:
		roots.append({"path": d, "scope": SCOPE_PROJECT})
	var user_dir := user_skills_dir()
	if not user_dir.is_empty():
		roots.append({"path": user_dir, "scope": SCOPE_USER})
	roots.append({"path": BUILTIN_DIR, "scope": SCOPE_BUILTIN})
	return roots

## Kökleri tarar: her alt klasörde tam adı `SKILL.md` olan dosya bir skill'dir. Aynı ad ikinci kez
## bulunursa ilk (yüksek öncelikli) kalır ve gölgelenen uyarıya yazılır.
## Kayıt: {name, description, location, dir, scope, warnings, fields}
static func discover(roots: Array[Dictionary] = default_roots()) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var by_name := {}
	for root: Dictionary in roots:
		var root_path := str(root.get("path", ""))
		if root_path.is_empty() or not DirAccess.dir_exists_absolute(root_path):
			continue
		for sub: String in DirAccess.get_directories_at(root_path):
			if sub.begins_with("."):
				continue
			var dir := root_path.path_join(sub)
			var md := dir.path_join("SKILL.md")
			if not FileAccess.file_exists(md):
				continue
			var parsed := AISidebarSkillParser.parse(FileAccess.get_file_as_string(md), sub)
			if parsed.get("ok", false) != true:
				push_warning("[Godot AI Skills] %s atlandı: %s" % [md, str(parsed.get("error", ""))])
				continue
			var name := str(parsed["name"])
			if by_name.has(name):
				var winner: Dictionary = by_name[name]
				var w: Array = winner["warnings"]
				w.append("shadows another skill with the same name at %s" % md)
				continue
			var rec := {
				"name": name,
				"description": str(parsed["description"]),
				"location": md,
				"dir": dir,
				"scope": str(root.get("scope", SCOPE_USER)),
				"warnings": parsed["warnings"],
				"fields": parsed["fields"],
			}
			by_name[name] = rec
			found.append(rec)
	return found

static func load_prefs() -> Dictionary:
	var v: Variant = AISidebarConfig.load_config().get(PREFS_KEY, {})
	return v if v is Dictionary else {}

static func is_enabled(skill: Dictionary, prefs: Dictionary) -> bool:
	var name := str(skill.get("name", ""))
	if prefs.has(name):
		return prefs[name] == true
	return str(skill.get("scope", "")) != SCOPE_PROJECT

static func set_enabled(name: String, enabled: bool) -> void:
	var cfg := AISidebarConfig.load_config()
	var prefs: Dictionary = cfg.get(PREFS_KEY, {}) if cfg.get(PREFS_KEY, {}) is Dictionary else {}
	prefs[name] = enabled
	cfg[PREFS_KEY] = prefs
	AISidebarConfig.save_config(cfg)

static func enabled_skills(roots: Array[Dictionary] = default_roots(), prefs: Dictionary = load_prefs()) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in discover(roots):
		if is_enabled(s, prefs):
			out.append(s)
	return out

static func find(name: String, skills: Array[Dictionary]) -> Dictionary:
	for s: Dictionary in skills:
		if str(s.get("name", "")) == name:
			return s
	return {}

## Model kataloğu (katman 1): yalnız açık skill'lerin adı ve açıklaması. Skill yoksa boş metin.
static func catalog_prompt(skills: Array[Dictionary]) -> String:
	if skills.is_empty():
		return ""
	var lines: PackedStringArray = []
	lines.append("=== SKILLS ===")
	lines.append("The following skills provide specialized instructions for specific tasks. When a task matches a skill's description, call the activate_skill tool with the skill's name before proceeding.")
	lines.append("<available_skills>")
	for s: Dictionary in skills:
		lines.append("  <skill><name>%s</name><description>%s</description></skill>" % [str(s["name"]), str(s["description"])])
	lines.append("</available_skills>")
	return "\n".join(lines)

## Etkinleştirme içeriği (katman 2): ön bilgisiz gövde, skill klasörü ve ek dosyaların listesi
## (katman 3 dosyaları okunmaz, yalnız adları verilir).
static func activation_content(skill: Dictionary) -> String:
	var parsed := AISidebarSkillParser.parse(FileAccess.get_file_as_string(str(skill.get("location", ""))), "")
	var body := str(parsed.get("body", ""))
	var lines: PackedStringArray = []
	lines.append("<skill_content name=\"%s\">" % str(skill.get("name", "")))
	lines.append(body)
	var resources := list_resources(str(skill.get("dir", "")))
	if resources.size() > 0:
		lines.append("")
		lines.append("Bundled files (read one with activate_skill and its `file` argument):")
		lines.append("<skill_resources>")
		for r: String in resources:
			lines.append("  <file>%s</file>" % r)
		lines.append("</skill_resources>")
	lines.append("</skill_content>")
	return "\n".join(lines)

## Skill klasöründeki SKILL.md dışındaki dosyalar (göreli yol, en fazla MAX_RESOURCES_LISTED).
static func list_resources(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	_collect(dir, "", out)
	return out

static func _collect(base: String, rel: String, out: PackedStringArray) -> void:
	var here := base if rel.is_empty() else base.path_join(rel)
	if not DirAccess.dir_exists_absolute(here):
		return
	for f: String in DirAccess.get_files_at(here):
		if out.size() >= MAX_RESOURCES_LISTED:
			return
		var r := f if rel.is_empty() else rel.path_join(f)
		if r != "SKILL.md" and not f.ends_with(".uid") and not f.ends_with(".import"):
			out.append(r)
	for d: String in DirAccess.get_directories_at(here):
		if not d.begins_with("."):
			_collect(base, d if rel.is_empty() else rel.path_join(d), out)

## Skill klasörü içindeki bir dosyayı okur; klasör dışına çıkan yol reddedilir.
static func read_resource(skill: Dictionary, rel_path: String) -> Dictionary:
	var rel := rel_path.replace("\\", "/").strip_edges()
	if rel.is_empty() or rel.begins_with("/") or rel.contains(":") or ".." in rel.split("/"):
		return {"ok": false, "error": "Invalid path inside the skill folder: " + rel_path}
	var path := str(skill.get("dir", "")).path_join(rel)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "No such file in skill '%s': %s" % [str(skill.get("name", "")), rel]}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "Cannot read: " + rel}
	var size := f.get_length()
	f.close()
	if size > MAX_RESOURCE_BYTES:
		return {"ok": false, "error": "File is too large to load (%d bytes): %s" % [size, rel]}
	return {"ok": true, "content": FileAccess.get_file_as_string(path)}

## Yeni skill iskeleti (kullanıcı ya da proje kapsamında). Dönüş: {ok, location | error}
static func create_skill(name: String, scope: String) -> Dictionary:
	if not AISidebarSkillParser.is_valid_name(name) or name.length() > AISidebarSkillParser.NAME_MAX:
		return {"ok": false, "error": "Use lowercase letters, digits and single hyphens (max 64)."}
	var root := user_skills_dir() if scope == SCOPE_USER else PROJECT_DIRS[0]
	if root.is_empty():
		return {"ok": false, "error": "The user home folder is unknown."}
	var dir := root.path_join(name)
	if DirAccess.dir_exists_absolute(dir):
		return {"ok": false, "error": "A skill folder with this name already exists: " + dir}
	DirAccess.make_dir_recursive_absolute(dir)
	var md := dir.path_join("SKILL.md")
	var f := FileAccess.open(md, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "Cannot write " + md}
	f.store_string("---\nname: %s\ndescription: What this skill does and when to use it (the agent decides from this sentence).\n---\n\n# %s\n\nStep-by-step instructions for the agent.\n" % [name, name])
	f.close()
	return {"ok": true, "location": md}

## Başka bir yerdeki skill klasörünü kullanıcı ya da proje kapsamına kopyalar.
static func import_skill(src_dir: String, scope: String) -> Dictionary:
	var src := src_dir.replace("\\", "/").trim_suffix("/")
	var md := src.path_join("SKILL.md")
	if not FileAccess.file_exists(md):
		return {"ok": false, "error": "The folder has no SKILL.md: " + src}
	var parsed := AISidebarSkillParser.parse(FileAccess.get_file_as_string(md), src.get_file())
	if parsed.get("ok", false) != true:
		return {"ok": false, "error": str(parsed.get("error", ""))}
	var root := user_skills_dir() if scope == SCOPE_USER else PROJECT_DIRS[0]
	var dst := root.path_join(src.get_file())
	if DirAccess.dir_exists_absolute(dst):
		return {"ok": false, "error": "A skill folder with this name already exists: " + dst}
	_copy_dir(src, dst)
	return {"ok": true, "location": dst.path_join("SKILL.md")}

static func _copy_dir(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	for f: String in DirAccess.get_files_at(src):
		DirAccess.copy_absolute(src.path_join(f), dst.path_join(f))
	for d: String in DirAccess.get_directories_at(src):
		if not d.begins_with("."):
			_copy_dir(src.path_join(d), dst.path_join(d))

## Kullanıcı / proje skill klasörünü siler (yerleşik skill silinmez, yalnız kapatılır).
static func delete_skill(skill: Dictionary) -> Dictionary:
	if str(skill.get("scope", "")) == SCOPE_BUILTIN:
		return {"ok": false, "error": "Built-in skills cannot be deleted; turn them off instead."}
	var dir := str(skill.get("dir", ""))
	if dir.is_empty() or not FileAccess.file_exists(dir.path_join("SKILL.md")):
		return {"ok": false, "error": "Not a skill folder: " + dir}
	_remove_dir(dir)
	return {"ok": true}

static func _remove_dir(dir: String) -> void:
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_remove_dir(dir.path_join(d))
	DirAccess.remove_absolute(dir)
