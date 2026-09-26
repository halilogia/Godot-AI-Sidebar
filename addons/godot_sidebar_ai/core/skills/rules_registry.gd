@tool
extends RefCounted
class_name AISidebarRulesRegistry

## Kurallar: her görevde geçerli, her turda modele giden düz Markdown talimatlar (agents.md açık
## formatı). İki kapsam:
##   global  ~/.agents/AGENTS.md, ~/.agents/rules/*.md             — bütün projelerinde geçerli, kişisel
##   project res://AGENTS.md, res://GEMINI.md, res://.agents/AGENTS.md,
##           res://.agents/rules/*.md                               — oyun deposuyla birlikte gider;
##           Codex / Cursor / Antigravity aynı dosyaları okur (Antigravity /learn'ün yazdığı yer dahil)
## Sıra: global önce, proje sonra (daha özel olan sonra gelir). Sidebar'ın sistem istemi (Ayarlar →
## Sistem Promptu) eklentinin kendi davranışıdır; kurallar onun üstüne eklenir, yerine geçmez.

const SCOPE_GLOBAL := "global"
const SCOPE_PROJECT := "project"
const PROJECT_FILES: Array[String] = ["res://AGENTS.md", "res://GEMINI.md", "res://.agents/AGENTS.md"]
const PROJECT_RULES_DIR := "res://.agents/rules"
## /learn ve "Kural ekle"nin yazdığı dosyalar (proje: Antigravity /learn ile aynı yer).
const PROJECT_LEARN_FILE := "res://.agents/rules/AGENTS.md"
const MAX_TOTAL_CHARS := 16000
const MAX_RULE_CHARS := 500

static func global_dir() -> String:
	var home := OS.get_environment("USERPROFILE")
	if home.is_empty():
		home = OS.get_environment("HOME")
	if home.is_empty():
		return ""
	return home.replace("\\", "/").path_join(".agents")

## Bulunan kural dosyaları, yükleme sırasıyla. Kayıt: {path, scope, chars}
static func discover(g_dir: String = global_dir(), project_files: Array[String] = PROJECT_FILES, project_rules_dir: String = PROJECT_RULES_DIR) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	if not g_dir.is_empty():
		_add(out, seen, g_dir.path_join("AGENTS.md"), SCOPE_GLOBAL)
		_add_dir(out, seen, g_dir.path_join("rules"), SCOPE_GLOBAL)
	for p: String in project_files:
		_add(out, seen, p, SCOPE_PROJECT)
	_add_dir(out, seen, project_rules_dir, SCOPE_PROJECT)
	return out

static func _add(out: Array[Dictionary], seen: Dictionary, path: String, scope: String) -> void:
	var key := ProjectSettings.globalize_path(path).replace("\\", "/").to_lower()
	if seen.has(key) or not FileAccess.file_exists(path):
		return
	seen[key] = true
	out.append({"path": path, "scope": scope, "chars": FileAccess.get_file_as_string(path).length()})

static func _add_dir(out: Array[Dictionary], seen: Dictionary, dir: String, scope: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for f: String in files:
		if f.to_lower().ends_with(".md"):
			_add(out, seen, dir.path_join(f), scope)

## Modele eklenecek metin (dosyalar yoksa ""). Toplam MAX_TOTAL_CHARS ile sınırlı.
static func prompt_text(files: Array[Dictionary] = discover()) -> String:
	if files.is_empty():
		return ""
	var parts: PackedStringArray = []
	parts.append("=== RULES (follow them; global rules apply to every project, project rules to this project and win on conflict) ===")
	var used := 0
	for f: Dictionary in files:
		var text := FileAccess.get_file_as_string(str(f["path"])).strip_edges()
		if text.is_empty():
			continue
		if used + text.length() > MAX_TOTAL_CHARS:
			text = text.left(maxi(0, MAX_TOTAL_CHARS - used)) + "\n[truncated: rules exceed %d characters]" % MAX_TOTAL_CHARS
		parts.append("--- %s rules: %s ---\n%s" % [str(f["scope"]), str(f["path"]), text])
		used += text.length()
		if used >= MAX_TOTAL_CHARS:
			break
	return "\n\n".join(parts)

## Kural dosyasına tek bir madde ekler (yoksa başlıkla oluşturur). Dönüş: {ok, path | error}
static func add_rule(rule: String, scope: String, g_dir: String = global_dir(), project_file: String = PROJECT_LEARN_FILE) -> Dictionary:
	var text := rule.strip_edges().replace("\r", "").replace("\n", " ")
	if text.is_empty():
		return {"ok": false, "error": "The rule is empty."}
	if text.length() > MAX_RULE_CHARS:
		return {"ok": false, "error": "Keep a rule under %d characters; put longer procedures in a skill." % MAX_RULE_CHARS}
	var path := project_file
	if scope == SCOPE_GLOBAL:
		if g_dir.is_empty():
			return {"ok": false, "error": "The user home folder is unknown."}
		path = g_dir.path_join("AGENTS.md")
	elif scope != SCOPE_PROJECT:
		return {"ok": false, "error": "scope must be project or global."}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var existing := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "# Rules\n"
	if not existing.ends_with("\n"):
		existing += "\n"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "Cannot write " + path}
	f.store_string(existing + "- " + text + "\n")
	f.close()
	return {"ok": true, "path": path}

## Bir kural dosyasını yoksa başlıkla oluşturur (Ayarlar → Kurallar). Dönüş: {ok, path}
static func ensure_file(path: String) -> Dictionary:
	if FileAccess.file_exists(path):
		return {"ok": true, "path": path}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "Cannot write " + path}
	f.store_string("# Rules\n\n- \n")
	f.close()
	return {"ok": true, "path": path}
