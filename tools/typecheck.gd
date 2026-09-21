@tool
extends SceneTree

## Godot AI Core - Headless GDScript Compilation & Scene Load Validator
## Eklenti (addons/godot_sidebar_ai) ve test (tests) altındaki tüm .gd ve .tscn dosyalarını
## Godot GUI açılmadan statik olarak yükleyip derler, sözdizimi ve sahne hatalarını yakalar.

func _init() -> void:
	print("==================================================")
	print("  GDScript Static Typecheck & Compilation Validator")
	print("==================================================")
	
	var gd_files: Array[String] = []
	var tscn_files: Array[String] = []
	
	_collect_files("res://addons/godot_sidebar_ai", gd_files, tscn_files)
	_collect_files("res://tests", gd_files, tscn_files)
	
	print("Bulunan dosyalar: %d GDScript (.gd), %d Sahne (.tscn)\n" % [gd_files.size(), tscn_files.size()])
	
	var passed_gd = 0
	var failed_gd = 0
	var errors: Array[String] = []
	
	# 1. GDScript derleme denetimi
	for f in gd_files:
		var script = load(f)
		if script is GDScript:
			passed_gd += 1
		else:
			failed_gd += 1
			errors.append("GDScript Derleme Hatası: " + f)
			
	# 2. TSCN sahne yükleme ve instantiate denetimi
	var passed_tscn = 0
	var failed_tscn = 0
	for s in tscn_files:
		var scene = load(s)
		if scene is PackedScene:
			var inst = (scene as PackedScene).instantiate()
			if inst:
				passed_tscn += 1
				inst.queue_free()
			else:
				failed_tscn += 1
				errors.append("Sahne Instantiate Hatası: " + s)
		else:
			failed_tscn += 1
			errors.append("Sahne Yükleme Hatası: " + s)
			
	print("--------------------------------------------------")
	print("Sonuç:")
	print(" - GDScript Dosyaları : %d/%d başarılı" % [passed_gd, gd_files.size()])
	print(" - Sahne Dosyaları    : %d/%d başarılı" % [passed_tscn, tscn_files.size()])
	print("--------------------------------------------------")
	
	if failed_gd == 0 and failed_tscn == 0:
		print("🎉 [TYPECHECK SUCCESS] Tüm GDScript ve Sahne dosyaları sözdizimi açısından kusursuz!")
		quit(0)
	else:
		printerr("❌ [TYPECHECK FAILED] %d hata tespit edildi:" % errors.size())
		for e in errors:
			printerr("   * " + e)
		quit(1)

func _collect_files(dir_path: String, gd_files: Array[String], tscn_files: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var full_path = dir_path + "/" + file_name
			if dir.current_is_dir():
				_collect_files(full_path, gd_files, tscn_files)
			else:
				if file_name.ends_with(".gd"):
					gd_files.append(full_path)
				elif file_name.ends_with(".tscn"):
					tscn_files.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
