extends SceneTree

## Dock'taki "Klip" düğmesinin yedek betiği: ana sahneyi verilen kare sayısı kadar çalıştırıp kapanır. Godot'nun film modu
## (--write-movie) kareleri sabit hızda yazar. Projede tools/devlog_clip.gd varsa dock onu kullanır (kamera koreografisi).
##   godot --path <proje> --write-movie out.avi --fixed-fps 30 -s res://addons/godot_sidebar_ai/core/capture/capture_clip.gd -- <kare>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var frames := int(args[0]) if args.size() > 0 else 300
	var main_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var packed := load(main_path) as PackedScene
	if packed == null:
		printerr("[capture_clip] Ana sahne yüklenemedi: ", main_path)
		quit(1)
		return
	root.add_child(packed.instantiate())
	for i in frames:
		await process_frame
	quit(0)
