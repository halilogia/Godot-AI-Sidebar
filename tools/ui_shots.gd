extends SceneTree

## Arayüz görsel kontrolü (CLAUDE.md → Arayüz grafik kalitesi standardı). Eklentinin GERÇEK bileşenlerini
## açar ve PNG kaydeder:
##   settings  Ayarlar penceresinin her sayfası (uzun sayfanın alt kısmı ayrıca) ve Yardım penceresi, geniş ve dar pencerede
##   dock      Sohbet paneli, tools/ui_scenarios.gd'deki her senaryoyla (karşılama, soru, onay, plan,
##             runtime, hata, kuyruk …), normal ve dar dock genişliğinde
## Arayüz değişikliğinden önce ve sonra çalıştırıp görüntüleri karşılaştırın; iki dilde bakın. Ölçek
## verilirse (ör. 1.5) editörün yüksek DPI ölçeği taklit edilir.
##
##   godot --path . -s res://tools/ui_shots.gd -- <çıktı klasörü (mutlak)> <tr|en> [all|settings|dock] [ölçek] [dark|light]
##
## Taşma bulunursa (pencere ekrana sığmaz ya da bir kart dock'tan geniş) "OVERFLOW" basılır, çıkış kodu 1.
## Headless değil (görüntü için pencere gerekir). config.json yalnız dil için geçici değişir; varsa bayt
## bayt geri yazılır, yoksa silinir. Senaryoların açtığı sohbet oturumları sonunda silinir.

const SettingsScene = preload("res://addons/godot_sidebar_ai/ui/dialogs/settings_dialog.tscn")
const AISidebarHelpDialog = preload("res://addons/godot_sidebar_ai/ui/dialogs/help_dialog.gd")
const AISidebarBugReportDialog = preload("res://addons/godot_sidebar_ai/ui/dialogs/bug_report_dialog.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarMotion = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_motion.gd")
const AISidebarTheme = preload("res://addons/godot_sidebar_ai/ui/theme/sidebar_theme.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")
const AISidebarUiScenarios = preload("res://tools/ui_scenarios.gd")

const SETTINGS_SIZES := {"wide": Vector2i(1280, 800), "narrow": Vector2i(900, 620)}
const DOCK_SIZES := {"dock": Vector2i(460, 900), "dock_narrow": Vector2i(320, 900)}

var _out := ""
var _lang := "tr"
var _what := "all"
var _overflows: Array[String] = []
var _sessions: Array[String] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir().path_join("ui_shots")
	_lang = args[1] if args.size() > 1 else "tr"
	_what = args[2] if args.size() > 2 else "all"
	if args.size() > 3:
		AISidebarTheme.ui_scale = maxf(0.5, args[3].to_float())
	if args.size() > 4 and args[4] == "light":
		AISidebarTheme.use_palette(true)
	DirAccess.make_dir_recursive_absolute(_out)
	# Fare girdisi kapalı: imleç pencerenin üstündeyse denetimler "üzerine gelindi" çizilmesin (kararlı görüntü).
	root.gui_disable_input = true
	_run.call_deferred()

func _run() -> void:
	var had_cfg := FileAccess.file_exists(AISidebarConfig.CONFIG_PATH)
	var raw_cfg := FileAccess.get_file_as_bytes(AISidebarConfig.CONFIG_PATH) if had_cfg else PackedByteArray()
	var cfg: Dictionary = AISidebarConfig.load_config()
	cfg["language"] = _lang
	# Geçiş animasyonları kapalı: görüntü geçişin ortasında yakalanmasın (karşılaştırma kararlı kalsın).
	cfg["ui_animations"] = false
	AISidebarConfig.save_config(cfg)
	AISidebarMotion.enabled = false

	if _what == "all" or _what == "settings":
		for size_name: String in SETTINGS_SIZES.keys():
			await _resize(_scaled(SETTINGS_SIZES[size_name]))
			await _shoot_settings(size_name, _scaled(SETTINGS_SIZES[size_name]))
	if _what == "all" or _what == "dock":
		# Araç süreleri geriye tarihlenir; işlem sayacı en uzun süreyi geçene kadar bekle.
		while Time.get_ticks_msec() < 4000:
			await process_frame
		for size_name: String in DOCK_SIZES.keys():
			await _resize(_scaled(DOCK_SIZES[size_name]))
			await _shoot_dock(size_name, _scaled(DOCK_SIZES[size_name]))

	if had_cfg:
		var f := FileAccess.open(AISidebarConfig.CONFIG_PATH, FileAccess.WRITE)
		f.store_buffer(raw_cfg)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AISidebarConfig.CONFIG_PATH))
	for id: String in _sessions:
		AISidebarChatManager.delete_session(id)
	print("[ui_shots] %s" % _out)
	for o: String in _overflows:
		printerr("[ui_shots] OVERFLOW " + o)
	quit(1 if not _overflows.is_empty() else 0)

## Pencere boyutları 1.0 ölçek içindir; ölçek verilince aynı mantıksal alan için büyütülür.
func _scaled(size: Vector2i) -> Vector2i:
	return Vector2i(Vector2(size) * AISidebarTheme.ui_scale)

func _resize(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size
	# Yeni boyut birkaç kare sonra etkin olur; pencere ona göre sığdırılsın.
	await _frames(4)

func _shoot_settings(size_name: String, size: Vector2i) -> void:
	var bg := ColorRect.new()
	bg.color = AISidebarTheme.COLOR_BG_APP
	bg.size = Vector2(size)
	root.add_child(bg)
	var dlg: AcceptDialog = SettingsScene.instantiate()
	root.add_child(dlg)
	await process_frame
	dlg.call("open_settings")
	var pages: Array = dlg.get("_pages")
	var scroll: ScrollContainer = dlg.get("_scroll")
	for i in pages.size():
		dlg.call("_select_category", i)
		await _frames(8)
		_save("%s_%s_%d" % [_lang, size_name, i])
		var r := Rect2i(dlg.position, dlg.size)
		if not Rect2i(Vector2i.ZERO, size).encloses(r):
			_overflows.append("%s page %d: dialog %s exceeds window %s" % [size_name, i, r, size])
		if scroll.get_v_scroll_bar().max_value > scroll.size.y + 1.0:
			scroll.scroll_vertical = 1000000
			await _frames(4)
			_save("%s_%s_%d_bottom" % [_lang, size_name, i])
	dlg.queue_free()
	var help := AISidebarHelpDialog.new()
	root.add_child(help)
	help.open_help()
	await _frames(8)
	_save("%s_%s_help" % [_lang, size_name])
	var hr := Rect2i(help.position, help.size)
	if not Rect2i(Vector2i.ZERO, size).encloses(hr):
		_overflows.append("%s help: dialog %s exceeds window %s" % [size_name, hr, size])
	var help_scroll: ScrollContainer = help.get("_scroll")
	help_scroll.scroll_vertical = 1000000
	await _frames(4)
	_save("%s_%s_help_bottom" % [_lang, size_name])
	help.queue_free()
	# Hata bildirme penceresi: boş hali ve rapor oluşturulmuş hali (zip geçici klasöre yazılıp silinir).
	var bug := AISidebarBugReportDialog.new()
	root.add_child(bug)
	bug.open_report({"chat_md": "# chat", "screenshot": Image.create(8, 8, false, Image.FORMAT_RGBA8), "out_dir": "user://ui_shots_bug_report", "clipboard": false})
	await _frames(8)
	_save("%s_%s_bug" % [_lang, size_name])
	var br := Rect2i(bug.position, bug.size)
	if not Rect2i(Vector2i.ZERO, size).encloses(br):
		_overflows.append("%s bug: dialog %s exceeds window %s" % [size_name, br, size])
	var made: Dictionary = bug.create_report()
	var bug_scroll: ScrollContainer = bug.get("_scroll")
	await _frames(4)
	bug_scroll.scroll_vertical = 1000000
	await _frames(4)
	_save("%s_%s_bug_done" % [_lang, size_name])
	if made.has("path"):
		DirAccess.remove_absolute(str(made["path"]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ui_shots_bug_report"))
	bug.queue_free()
	bg.queue_free()
	await _frames(2)

func _shoot_dock(size_name: String, size: Vector2i) -> void:
	for scenario: String in AISidebarUiScenarios.NAMES:
		var scenarios := AISidebarUiScenarios.new(_lang)
		var made: Dictionary = await scenarios.create_dock(root)
		var dock: Control = made["dock"]
		scenarios.play(scenario, dock, made["runner"])
		await _frames(12)
		_save("%s_%s_%s" % [_lang, size_name, scenario])
		_check_dock_overflow(dock, "%s %s" % [size_name, scenario], size)
		_sessions.append(str(dock.get("sessions").call("current_id")))
		dock.free()
		var host: Node = made["host"]
		host.free()
		await _frames(2)

## Dock içindeki görünür bir denetim dock'un sağ kenarını aşıyorsa taşmadır (dar dock'ta en sık hata).
func _check_dock_overflow(dock: Control, label: String, size: Vector2i) -> void:
	var limit := float(size.x) + 1.0
	var widest := _widest_right(dock)
	if widest > limit:
		_overflows.append("%s: content reaches x=%d, dock is %d wide" % [label, int(widest), size.x])

func _widest_right(n: Node) -> float:
	var right := 0.0
	if n is Control:
		var c: Control = n
		if not c.is_visible_in_tree():
			return 0.0
		right = c.get_global_rect().end.x
	for ch: Node in n.get_children():
		right = maxf(right, _widest_right(ch))
	return right

func _frames(n: int) -> void:
	for _f in n:
		await process_frame

func _save(name: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
