extends SceneTree

## README görsellerini eklentinin GERÇEK arayüz bileşenlerinden üretir (SRP: yalnızca görsel).
## Dock sahnesi gerçek AgentRunner sinyalleriyle sürülür; modele bağlanılmaz, konuşma içeriği
## senaryoludur. Arayüz değiştiğinde görselleri yeniden üretmek için tekrar çalıştırın.
##
## Windows / macOS (pencere açılır, birkaç saniye sonra kapanır):
##   godot --path . -s res://tools/readme_shots.gd -- docs/media en
## Linux headless sunucu (sanal ekran gerekir):
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://tools/readme_shots.gd -- docs/media en
##
## Argümanlar: <çıktı klasörü> <dil: en|tr>. config.json dili geçici değiştirilir ve
## bitince dosya birebir geri yazılır.

const AISidebarUiScenarios = preload("res://tools/ui_scenarios.gd")
const AISidebarConfig = preload("res://addons/godot_sidebar_ai/core/config/api_config.gd")
const AISidebarChatManager = preload("res://addons/godot_sidebar_ai/core/chat/chat_manager.gd")

const WIDTH := 460

var _out_dir := "docs/media"
var _lang := "en"
var _sessions: Array = []

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	if args.size() > 1:
		_lang = args[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out_dir))
	_run.call_deferred()

func _run() -> void:
	# Tool süreleri geriye tarihlenir; işlem sayacı en uzun süreyi geçene kadar bekle.
	while Time.get_ticks_msec() < 4000:
		await process_frame
	var had_cfg = FileAccess.file_exists(AISidebarConfig.CONFIG_PATH)
	var raw_cfg = FileAccess.get_file_as_string(AISidebarConfig.CONFIG_PATH) if had_cfg else ""
	var cfg = AISidebarConfig.load_config()
	cfg["language"] = _lang
	cfg["auto_approve_mode"] = "MANUAL"
	AISidebarConfig.save_config(cfg)

	await _shot("hero", 740, true)
	await _shot("clarification", 0, false)
	await _shot("approval", 0, false)
	await _shot("plan", 0, false)
	await _shot("runtime", 0, false)

	if had_cfg:
		var f = FileAccess.open(AISidebarConfig.CONFIG_PATH, FileAccess.WRITE)
		f.store_string(raw_cfg)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AISidebarConfig.CONFIG_PATH))
	for id in _sessions:
		AISidebarChatManager.delete_session(id)
	quit()

## Bir senaryoyu yeni bir dock'ta oynatır ve PNG kaydeder. full=true tüm dock'u, false yalnızca
## sohbet akışının içeriğini kırpar. Senaryolar tools/ui_scenarios.gd'dedir.
func _shot(name: String, height: int, full: bool) -> void:
	root.size = Vector2i(WIDTH, height if height > 0 else 1400)
	var scenarios = AISidebarUiScenarios.new(_lang)
	var made: Dictionary = await scenarios.create_dock(root)
	var dock = made["dock"]
	scenarios.play(name, dock, made["runner"])
	for i in 12:
		await process_frame
	var img = root.get_texture().get_image()
	if not full:
		var top = dock.message_stream.get_global_rect().position.y
		var bottom = top
		for c in dock.message_stream.get_children():
			if c is Control and c.visible and not c.is_queued_for_deletion():
				bottom = maxf(bottom, c.get_global_rect().end.y)
		img = img.get_region(Rect2i(0, int(top) - 4, WIDTH, int(bottom - top) + 12))
	var path = ProjectSettings.globalize_path("res://" + _out_dir.path_join(name + "_" + _lang + ".png"))
	img.save_png(path)
	print("saved ", path)
	_sessions.append(dock.sessions.current_id())
	dock.free()
	made["host"].free()
