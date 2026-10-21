extends SceneTree

## Dock'taki "Ekran görüntüsü" düğmesinin çalıştırdığı betik: projenin ana sahnesini açar, bekler ve oyunun kendi
## viewport görüntüsünü PNG yazar (tools/game_shot.gd ile aynı okuma; eklenti içinde olduğu için her projede çalışır).
##   godot --path <proje> -s res://addons/godot_sidebar_ai/core/capture/capture_shot.gd -- <çıktı.png> [bekleme_sn=3]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://game_shot.png"
	var wait_sec := float(args[1]) if args.size() > 1 else 3.0
	var main_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var packed := load(main_path) as PackedScene
	if packed == null:
		printerr("[capture_shot] Ana sahne yüklenemedi: ", main_path)
		quit(1)
		return
	root.add_child(packed.instantiate())
	await create_timer(wait_sec).timeout
	await process_frame
	var err := root.get_texture().get_image().save_png(out)
	print("[capture_shot] ", out, " err=", err)
	quit(0 if err == OK else 1)
