@tool
extends RefCounted
class_name AISidebarBugReport

## Hata raporu paketi (Yardım / Ayarlar → Genel / `/bug`). Tek zip üretir, hiçbir yere göndermez:
##   report.md          issue metni (açıklama, ortam, son görevin durumu), seçili dilde
##   environment.json   eklenti / Godot / işletim sistemi / ekran kartı / seçili sağlayıcı ve model
##   settings.json      ayarlardan yalnız güvenli alanlar (izin listesi): anahtar ve token yazılmaz,
##                      yalnız dolu mu boş mu; base_url'den yalnız adres; sistem istemi yalnız
##                      varsayılan mı özelleştirilmiş mi
##   chat.md            (isteğe bağlı) sohbet ve görev kaydı, dışa aktarmadaki maskelemeyle
##   godot_log_tail.txt (isteğe bağlı) oyun logunun son satırları, gizli bilgi desenleri maskeli
##   sidebar.png        (isteğe bağlı) panelin görüntüsü
## Kullanıcı zip'i issue'ya kendisi ekler; GitHub sayfası yalnız kullanıcı tıklayınca açılır.

const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarI18n = preload("res://addons/godot_sidebar_ai/core/i18n/i18n.gd")
const AISidebarTaskTranscript = preload("res://addons/godot_sidebar_ai/core/chat/task_transcript.gd")

const ISSUES_URL := "https://github.com/halilogia/Godot-AI-Sidebar/issues/new"
const OUT_DIR := "user://ai_sidebar_bug_reports"
const PLUGIN_CFG := "res://addons/godot_sidebar_ai/plugin.cfg"
const LOG_PATH := "user://logs/godot.log"
const LOG_TAIL_LINES := 200
## Ayarlardan olduğu gibi yazılabilen alanlar; listede olmayan hiçbir alan rapora girmez.
const SAFE_SETTINGS: Array[String] = [
	"config_version", "provider_type", "selected_model", "language", "stream", "vision_capable",
	"temperature", "goal_max_rounds", "auto_approve_mode", "require_delete_approval",
	"require_overwrite_approval", "ui_animations", "mcp_bridge_enabled", "mcp_bridge_port", "blender_bridge_enabled",
]

## Eklenti, motor, sistem ve seçili sağlayıcı bilgisi. `extra` arayüzden gelen ek alanlar (ör. ölçek).
static func environment(extra: Dictionary = {}) -> Dictionary:
	var cfg := AISidebarConfig.load_config()
	var plugin := ConfigFile.new()
	var plugin_version := ""
	if plugin.load(PLUGIN_CFG) == OK:
		plugin_version = str(plugin.get_value("plugin", "version", ""))
	var env := {
		"plugin_version": plugin_version,
		"godot_version": str(Engine.get_version_info().get("string", "")),
		"os": OS.get_name() + " " + OS.get_version(),
		"locale": OS.get_locale(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"provider_type": str(cfg.get("provider_type", "")),
		"selected_model": str(cfg.get("selected_model", "")),
		"language": AISidebarI18n.get_current_language(),
		"created_at": Time.get_datetime_string_from_system(),
	}
	env.merge(extra, true)
	return env

## Ayarların rapora girebilen hali (izin listesi). Gizli değerler yalnız "dolu / boş" olarak görünür.
static func safe_settings(cfg: Dictionary) -> Dictionary:
	var out := {}
	for key: String in SAFE_SETTINGS:
		if cfg.has(key):
			out[key] = cfg[key]
	out["api_key"] = "set" if not str(cfg.get("api_key", "")).is_empty() else "empty"
	out["mcp_bridge_token"] = "set" if not str(cfg.get("mcp_bridge_token", "")).is_empty() else "empty"
	out["blender_bridge_token"] = "set" if not str(cfg.get("blender_bridge_token", "")).is_empty() else "empty"
	out["base_url_host"] = url_host(str(cfg.get("base_url", "")))
	out["system_prompt"] = "default" if str(cfg.get("system_prompt", "")) == str(AISidebarConfig.DEFAULT_CONFIG["system_prompt"]) else "custom"
	var models: Variant = cfg.get("cached_models", [])
	var model_list: Array = models if models is Array else []
	out["cached_models_count"] = model_list.size()
	return out

## Adresin yalnız şema + ana bilgisayar + port kısmı (kullanıcı bilgisi, yol ve sorgu atılır).
static func url_host(url: String) -> String:
	var u := url.strip_edges()
	if u.is_empty():
		return ""
	var scheme := ""
	var i := u.find("://")
	if i >= 0:
		scheme = u.substr(0, i + 3)
		u = u.substr(i + 3)
	for sep: String in ["/", "?", "#"]:
		var j := u.find(sep)
		if j >= 0:
			u = u.substr(0, j)
	var at := u.rfind("@")
	if at >= 0:
		u = u.substr(at + 1)
	return scheme + u

## Oyun logunun son satırları, gizli bilgi desenleri maskeli. Log yoksa boş.
static func log_tail(path: String = LOG_PATH, max_lines: int = LOG_TAIL_LINES) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var start := maxi(0, lines.size() - max_lines)
	return AISidebarTaskTranscript.redact_secrets("\n".join(lines.slice(start)))

## Issue metni (seçili dilde): açıklama, ortam tablosu, son görevin durumu ve paketin adı.
static func issue_markdown(description: String, env: Dictionary, last_task: Dictionary, zip_name: String) -> String:
	var lines := PackedStringArray()
	lines.append("### " + AISidebarI18n.get_text("bug_md_description"))
	lines.append("")
	var desc := AISidebarTaskTranscript.redact_secrets(description.strip_edges())
	lines.append(desc if not desc.is_empty() else "_" + AISidebarI18n.get_text("bug_md_no_description") + "_")
	lines.append("")
	lines.append("### " + AISidebarI18n.get_text("bug_md_environment"))
	lines.append("")
	lines.append("| | |")
	lines.append("|---|---|")
	for key: String in ["plugin_version", "godot_version", "os", "renderer", "video_adapter", "editor_scale", "palette", "language", "provider_type", "selected_model"]:
		if env.has(key):
			lines.append("| %s | %s |" % [key, str(env[key]).replace("|", "/")])
	lines.append("")
	if not last_task.is_empty():
		lines.append("### " + AISidebarI18n.get_text("bug_md_last_task"))
		lines.append("")
		lines.append("- status: `%s`" % str(last_task.get("status", "")))
		var code := str(last_task.get("stop_code", ""))
		if not code.is_empty():
			lines.append("- stop_code: `%s`" % code)
		var reason := AISidebarTaskTranscript.redact_secrets(str(last_task.get("stop_reason", "")))
		if not reason.is_empty():
			lines.append("- stop_reason: " + reason.left(500).replace("\n", " "))
		lines.append("")
	lines.append("### " + AISidebarI18n.get_text("bug_md_attachment"))
	lines.append("")
	lines.append(AISidebarI18n.get_text("bug_md_attachment_hint", {"file": zip_name}))
	lines.append("")
	return "\n".join(lines)

## Paketi yazar. `parts`: {"chat_md": String, "screenshot": Image, "include_log": bool}; boş olanlar
## eklenmez. Dönen: {"ok", "path" (mutlak zip yolu), "markdown", "files", "error"}.
static func build(description: String, env: Dictionary, last_task: Dictionary, parts: Dictionary, out_dir: String = OUT_DIR) -> Dictionary:
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var zip_name := "ai_sidebar_bug_%s.zip" % stamp
	var dir_abs := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(dir_abs)
	var zip_path := dir_abs.path_join(zip_name)
	var markdown := issue_markdown(description, env, last_task, zip_name)

	var files := {
		"report.md": markdown.to_utf8_buffer(),
		"environment.json": JSON.stringify(env, "  ").to_utf8_buffer(),
		"settings.json": JSON.stringify(safe_settings(AISidebarConfig.load_config()), "  ").to_utf8_buffer(),
	}
	var chat_md := str(parts.get("chat_md", ""))
	if not chat_md.is_empty():
		files["chat.md"] = chat_md.to_utf8_buffer()
	if parts.get("include_log", false) == true:
		var tail := log_tail()
		if not tail.is_empty():
			files["godot_log_tail.txt"] = tail.to_utf8_buffer()
	var shot_v: Variant = parts.get("screenshot", null)
	if shot_v is Image:
		var shot: Image = shot_v
		if not shot.is_empty():
			files["sidebar.png"] = shot.save_png_to_buffer()

	var zip := ZIPPacker.new()
	var err := zip.open(zip_path)
	if err != OK:
		return {"ok": false, "error": error_string(err), "path": zip_path, "markdown": markdown, "files": []}
	for name: String in files.keys():
		var data: PackedByteArray = files[name]
		zip.start_file(name)
		zip.write_file(data)
		zip.close_file()
	zip.close()
	return {"ok": true, "error": "", "path": zip_path, "markdown": markdown, "files": files.keys()}
