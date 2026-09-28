extends SceneTree

## Bir oyun projesinin ana sahnesini açıp birkaç saniye sonra oyunun kendi viewport görüntüsünü PNG olarak
## yazar (pencere yakalama değil; ajanın take_runtime_screenshot'ı ile aynı okuma). Demoların gerçek görünümünü
## karşılaştırmak için (görsel skill'lerin önce / sonra ölçümü).
##
##   godot --path <proje> -s <bu dosyanın mutlak yolu> -- <çıktı.png> [bekleme_sn=3] [genişlik=1152] [yükseklik=648]
## Pencere gerekir (headless çizmez). Tuş göndermez: oyun kendi açılış durumunda görüntülenir.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://game_shot.png"
	var wait_sec := float(args[1]) if args.size() > 1 else 3.0
	var w := int(args[2]) if args.size() > 2 else 1152
	var h := int(args[3]) if args.size() > 3 else 648
	root.size = Vector2i(w, h)
	var main_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var packed := load(main_path) as PackedScene
	if packed == null:
		printerr("[game_shot] Ana sahne yüklenemedi: ", main_path)
		quit(1)
		return
	root.add_child(packed.instantiate())
	await create_timer(wait_sec).timeout
	await process_frame
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("[game_shot] ", out, " ", img.get_width(), "x", img.get_height(), " err=", err)
	quit(0)
