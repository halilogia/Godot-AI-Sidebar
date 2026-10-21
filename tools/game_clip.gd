extends SceneTree

## Evrensel oyun klibi (yedek betik): projenin ana sahnesini açar ve verilen kare sayısı kadar çalıştırıp kapanır.
## game_clip.ps1 bunu yalnız projede kendi koreografisi yoksa (tools/devlog_clip.gd) kullanır; Godot'nun film modu
## (--write-movie) kareleri sabit hızda yazar, bu yüzden "bekleme" gerçek süre değil kare sayısıdır.
##
##   godot --path <proje> --resolution 1080x1920 --write-movie out.avi --fixed-fps 30 -s <bu dosyanın mutlak yolu> -- <kare sayısı>
## Pencere gerekir (headless çizmez). Oyun kendi açılış durumunda, kendi animasyonlarıyla kaydedilir.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var frames := int(args[0]) if args.size() > 0 else 300
	var main_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var packed := load(main_path) as PackedScene
	if packed == null:
		printerr("[game_clip] Ana sahne yüklenemedi: ", main_path)
		quit(1)
		return
	root.add_child(packed.instantiate())
	for i in frames:
		await process_frame
	print("[game_clip] ", frames, " kare yazıldı")
	quit(0)
