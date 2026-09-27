@tool
extends Node
class_name AISidebarEditorSmoke

## Gerçek editörde küçük duman testi (tools/editor_smoke.ps1 başlatır). Yalnız editör
## `-- --ai-sidebar-smoke=<mutlak klasör>` ile açılınca plugin.gd kurar; normal kullanımda hiç çalışmaz.
## Tek senaryo: panel yüklendi mi, tema ve durum rozeti yerinde mi, Ayarlar ve Yardım açılıyor mu; panelin,
## Ayarlar'ın ve Yardım'ın editördeki GERÇEK görüntüsü (editör teması, ölçek, yazı tipleri) kaydedilir,
## report.json yazılır ve editör kapanır. Betik hatalarını betik editör çıktısından okur.

const AISidebarThemeBuilder = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme_builder.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")

const FLAG := "--ai-sidebar-smoke="
const SETTLE_SEC := 4.0

var out_dir: String = ""
var dock: Control = null
var _checks: Array[Dictionary] = []

## Editör bu bayrakla açıldıysa çıktı klasörü, değilse boş.
static func requested_out_dir() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(FLAG):
			return a.trim_prefix(FLAG)
	return ""

func _ready() -> void:
	name = "AISidebarEditorSmoke"
	_run.call_deferred()

func _check(id: String, ok: bool, detail: String = "") -> void:
	_checks.append({"id": id, "ok": ok, "detail": detail})

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _wait(SETTLE_SEC)
	_check("dock_exists", dock != null and is_instance_valid(dock))
	if dock == null:
		_finish()
		return
	# Panel bir sekme grubundaysa sekmesini öne getir.
	var parent := dock.get_parent()
	if parent is TabContainer:
		var tabs: TabContainer = parent
		tabs.current_tab = tabs.get_tab_idx_from_control(dock)
	await _wait(0.5)
	_check("dock_visible", dock.is_visible_in_tree())
	var th: Theme = dock.theme
	_check("dock_theme", th != null and th.get_type_variation_base(AISidebarThemeBuilder.CARD) == &"PanelContainer")
	var badge: Label = dock.get("status_badge")
	_check("status_badge_text", badge != null and not badge.text.is_empty(), badge.text if badge else "")
	_check("editor_scale", true, str(EditorInterface.get_editor_scale()))
	_check("palette", true, "light" if AISidebarTheme.is_light else "dark")
	_save(dock.get_viewport().get_texture().get_image(), "editor_window.png", Rect2i())
	_save(dock.get_viewport().get_texture().get_image(), "sidebar.png", Rect2i(dock.get_global_rect()))

	var settings: Window = dock.get("settings_dialog")
	if settings and settings.has_method("open_settings"):
		settings.call("open_settings")
		await _wait(1.0)
		_check("settings_opens", settings.visible)
		_save_window(settings, "settings.png")
		settings.hide()
	else:
		_check("settings_opens", false, "settings_dialog missing")

	var help: Window = dock.get("help_dialog")
	if help and help.has_method("open_help"):
		help.call("open_help")
		await _wait(1.0)
		_check("help_opens", help.visible)
		_save_window(help, "help.png")
		help.hide()
	else:
		_check("help_opens", false, "help_dialog missing")
	_finish()

## Ayrı pencere (tek pencere kipi kapalıyken ayrı işletim sistemi penceresi): kendi görüntüsü; gömülü
## pencerede ana görüntüden kendi dikdörtgeni.
func _save_window(w: Window, file: String) -> void:
	if w.is_embedded():
		_save(dock.get_viewport().get_texture().get_image(), file, Rect2i(w.position, w.size))
	else:
		_save(w.get_texture().get_image(), file, Rect2i())

func _save(img: Image, file: String, crop: Rect2i) -> void:
	if img == null or img.is_empty():
		_check("screenshot_" + file, false, "empty image")
		return
	var out := img
	if crop.size != Vector2i.ZERO:
		var r := Rect2i(Vector2i.ZERO, img.get_size()).intersection(crop)
		if r.size.x > 0 and r.size.y > 0:
			out = img.get_region(r)
	out.save_png(out_dir.path_join(file))

func _finish() -> void:
	var failed := _checks.filter(func(c: Dictionary) -> bool: return c["ok"] != true)
	var report := {
		"godot": Engine.get_version_info().get("string", ""),
		"passed": _checks.size() - failed.size(),
		"failed": failed.size(),
		"checks": _checks,
	}
	var f := FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	else:
		push_error("[ai-sidebar-smoke] report.json yazılamadı: " + out_dir)
	# Rapor yazılamasa da editör kapanır; betik zaman aşımını beklemez.
	print("[ai-sidebar-smoke] passed=%d failed=%d -> %s" % [report["passed"], report["failed"], out_dir])
	get_tree().quit(0 if failed.is_empty() else 1)
