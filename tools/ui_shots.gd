extends SceneTree

## Arayüz görsel kontrolü (CLAUDE.md → Arayüz grafik kalitesi standardı): Ayarlar penceresini GERÇEK bileşenleriyle açar ve her sayfanın
## PNG'sini alır; uzun sayfaların alt kısmı da ayrıca çekilir. İki pencere boyutunda (geniş, dar) çekildiği
## için sığma / kırpılma sorunları da görünür. Arayüz değişikliğinden önce ve sonra çalıştırıp görüntüleri
## karşılaştırın; iki dilde de bakın.
##
##   godot --path . -s res://tools/ui_shots.gd -- <çıktı klasörü (mutlak)> <dil: tr|en>
##
## Pencere ekrana sığmazsa (ör. uzun metin bir denetimi genişletirse) "OVERFLOW" satırı basılır, çıkış kodu 1 olur.
## Headless değil (görüntü için pencere gerekir). config.json yalnız dil için geçici değişir; varsa
## bayt bayt geri yazılır, yoksa silinir.

const SettingsScene = preload("res://addons/godot_sidebar_ai/ui/dialogs/settings_dialog.tscn")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")

const SIZES := {"wide": Vector2i(1280, 800), "narrow": Vector2i(900, 620)}

var _out := ""
var _lang := "tr"
var _overflows: Array[String] = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir().path_join("ui_shots")
	_lang = args[1] if args.size() > 1 else "tr"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()

func _run() -> void:
	var had_cfg := FileAccess.file_exists(AISidebarConfig.CONFIG_PATH)
	var raw_cfg := FileAccess.get_file_as_bytes(AISidebarConfig.CONFIG_PATH) if had_cfg else PackedByteArray()
	var cfg: Dictionary = AISidebarConfig.load_config()
	cfg["language"] = _lang
	AISidebarConfig.save_config(cfg)

	for size_name: String in SIZES.keys():
		var size: Vector2i = SIZES[size_name]
		DisplayServer.window_set_size(size)
		root.size = size
		# Yeni boyut birkaç kare sonra etkin olur; pencere ona göre sığdırılsın.
		await _frames(4)
		await _shoot(size_name, size)

	if had_cfg:
		var f := FileAccess.open(AISidebarConfig.CONFIG_PATH, FileAccess.WRITE)
		f.store_buffer(raw_cfg)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AISidebarConfig.CONFIG_PATH))
	print("[ui_shots] %s" % _out)
	for o: String in _overflows:
		printerr("[ui_shots] OVERFLOW " + o)
	quit(1 if not _overflows.is_empty() else 0)

func _shoot(size_name: String, size: Vector2i) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12)
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
	bg.queue_free()
	await _frames(2)

func _frames(n: int) -> void:
	for _f in n:
		await process_frame

func _save(name: String) -> void:
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
