@tool
extends RefCounted

const AISidebarScriptTools = preload("res://addons/godot_sidebar_ai/core/tools/primitive/script_tools.gd")
const AISidebarVerificationPipeline = preload("res://addons/godot_sidebar_ai/core/verification/verification_pipeline.gd")

static func run() -> Dictionary:
	var passed = 0
	var failed = 0
	var errors: Array = []
	
	var path_a_gd = "res://tests/temp_a.gd"
	var path_b_tscn = "res://tests/temp_b.tscn"
	var path_c_tscn = "res://tests/temp_c.tscn"
	var path_bad_gd = "res://tests/temp_bad.gd"
	
	# Temizlik
	for p in [path_a_gd, path_b_tscn, path_c_tscn, path_bad_gd]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
			
	# Test A: player.gd ve Player.tscn referansı (aynı batch içinde)
	var batch_a = [
		{"file_path": path_b_tscn, "content": "[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"" + path_a_gd + "\" id=\"1_a\"]\n[node name=\"Player\" type=\"CharacterBody3D\"]\n"},
		{"file_path": path_a_gd, "content": "extends CharacterBody3D\nfunc _physics_process(delta):\n\tpass\n"}
	]
	var res_a = AISidebarScriptTools.execute("write_files", {"files": batch_a})
	if res_a.get("success", false) and FileAccess.file_exists(path_a_gd) and FileAccess.file_exists(path_b_tscn):
		passed += 1
	else:
		failed += 1
		errors.append("Test A Başarısız: Batch içi script-tscn referansı geçemedi: " + str(res_a))
		
	# Temizlik
	for p in [path_a_gd, path_b_tscn]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
			
	# Test B: Yeni sahne -> yeni script aynı batch
	var batch_b = [
		{"file_path": path_a_gd, "content": "extends Node\nfunc _ready():\n\tprint('test')\n"},
		{"file_path": path_b_tscn, "content": "[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"" + path_a_gd + "\" id=\"1_x\"]\n[node name=\"Root\" type=\"Node\"]\n"}
	]
	var res_b = AISidebarScriptTools.execute("write_files", {"files": batch_b})
	if res_b.get("success", false) and FileAccess.file_exists(path_a_gd) and FileAccess.file_exists(path_b_tscn):
		passed += 1
	else:
		failed += 1
		errors.append("Test B Başarısız: " + str(res_b))
		
	# Temizlik
	for p in [path_a_gd, path_b_tscn]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
			
	# Test C: Gerçekte olmayan external resource referansı
	var batch_c = [
		{"file_path": path_b_tscn, "content": "[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"res://non_existent_ghost_file.gd\" id=\"1_g\"]\n[node name=\"Ghost\" type=\"Node\"]\n"}
	]
	var res_c = AISidebarScriptTools.execute("write_files", {"files": batch_c})
	var err_c = res_c.get("error", {})
	if not res_c.get("success", false) and err_c.get("code") == "RESOURCE_REFERENCE_NOT_FOUND" and not FileAccess.file_exists(path_b_tscn):
		passed += 1
	else:
		failed += 1
		errors.append("Test C Başarısız: Olmayan external resource tespit edilemedi: " + str(res_c))
		
	# Test D: Bir dosyada syntax error varsa diğer hiçbir dosya yazılmamalı
	var batch_d = [
		{"file_path": path_a_gd, "content": "extends Node\nfunc _ready():\n\tpass\n"},
		{"file_path": path_bad_gd, "content": "extends Node\nfunc broken_syntax(:\n"}
	]
	var res_d = AISidebarScriptTools.execute("write_files", {"files": batch_d})
	if not res_d.get("success", false) and not FileAccess.file_exists(path_a_gd) and not FileAccess.file_exists(path_bad_gd):
		passed += 1
	else:
		failed += 1
		errors.append("Test D Başarısız: Syntax error içeren batch'te atomiklik bozuldu!")
		
	# Test E: 3-File dependency graph (A.gd, B.tscn -> A.gd, C.tscn -> B.tscn)
	var batch_e = [
		{"file_path": path_c_tscn, "content": "[gd_scene load_steps=2 format=3]\n[ext_resource type=\"PackedScene\" path=\"" + path_b_tscn + "\" id=\"1_b\"]\n[node name=\"Level\" type=\"Node3D\"]\n"},
		{"file_path": path_b_tscn, "content": "[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"" + path_a_gd + "\" id=\"1_a\"]\n[node name=\"Player\" type=\"CharacterBody3D\"]\n"},
		{"file_path": path_a_gd, "content": "extends CharacterBody3D\nfunc _physics_process(delta):\n\tpass\n"}
	]
	var res_e = AISidebarScriptTools.execute("write_files", {"files": batch_e})
	if res_e.get("success", false) and FileAccess.file_exists(path_a_gd) and FileAccess.file_exists(path_b_tscn) and FileAccess.file_exists(path_c_tscn):
		passed += 1
	else:
		failed += 1
		errors.append("Test E Başarısız: 3-file dependency graph batch başarısız oldu: " + str(res_e))

	# Test F (bulgu #21): batch içi .gd bağımlılığı istisnası gerçek sözdizimi /
	# üye hatalarını gizlememeli; geçerli bağımlılık yine geçmeli.
	var fa = "res://tests/temp_dep_f_a.gd"
	var fb = "res://tests/temp_dep_f_b.gd"
	var fb_src = "extends Node\nstatic func hi():\n\treturn 1\n"
	var f_cases = [
		["valid_dep", "extends Node\nconst B = preload(\"%s\")\nfunc f():\n\treturn B.hi()\n" % fb, true],
		["valid_extends_dep", "extends \"%s\"\nfunc g():\n\treturn hi()\n" % fb, true],
		["syntax_error_with_dep", "extends Node\nconst B = preload(\"%s\")\nfunc f(:\n\treturn B.hi()\n" % fb, false],
		["missing_member_on_dep", "extends Node\nconst B = preload(\"%s\")\nfunc f():\n\treturn B.nope()\n" % fb, false],
		["syntax_error_self_mention", "extends Node\n# %s\nfunc f(:\n\tpass\n" % fa, false],
	]
	var f_bad: Array = []
	for fc in f_cases:
		var fres = AISidebarVerificationPipeline.validate_batch_files([
			{"file_path": fa, "content": fc[1]},
			{"file_path": fb, "content": fb_src}
		])
		if bool(fres.get("success", false)) != bool(fc[2]):
			f_bad.append(str(fc[0]) + " success=" + str(fres.get("success", false)))
	var mirror_left = DirAccess.dir_exists_absolute("user://ai_sidebar_verify") and not DirAccess.get_directories_at("user://ai_sidebar_verify").is_empty()
	if f_bad.is_empty() and not FileAccess.file_exists(fa) and not FileAccess.file_exists(fb) and not mirror_left:
		passed += 1
	else:
		failed += 1
		errors.append("Test F Başarısız: batch bağımlılık istisnası: " + str(f_bad) + " mirror_left=" + str(mirror_left))

	# Test G: aynı batch'te yeni class_name'lere başvuru (preload yok), karşılıklı başvuru dahil;
	# gerçek üye hatası yine yakalanır. (Benchmark: GameData / Province / GameState batch'i reddediliyordu.)
	var ga = "res://tests/temp_cls_g_data.gd"
	var gb = "res://tests/temp_cls_g_state.gd"
	var gc = "res://tests/temp_cls_g_ai.gd"
	var g_data = "class_name TempClsGData\nextends RefCounted\nenum T { SEA, LAND }\nstatic func is_sea(t: int) -> bool:\n\treturn t == T.SEA\n"
	var g_state = "class_name TempClsGState\nextends Node\nvar terrain: int = TempClsGData.T.LAND\nfunc tick() -> void:\n\tTempClsGAi.think(self)\n"
	var g_ai_ok = "class_name TempClsGAi\nextends RefCounted\nstatic func think(s: TempClsGState) -> bool:\n\treturn TempClsGData.is_sea(s.terrain)\n"
	var g_ai_bad = "class_name TempClsGAi\nextends RefCounted\nstatic func think(s: TempClsGState) -> bool:\n\treturn TempClsGData.nope(s.terrain)\n"
	var g_ok = AISidebarVerificationPipeline.validate_batch_files([
		{"file_path": ga, "content": g_data}, {"file_path": gb, "content": g_state}, {"file_path": gc, "content": g_ai_ok}])
	var g_bad = AISidebarVerificationPipeline.validate_batch_files([
		{"file_path": ga, "content": g_data}, {"file_path": gb, "content": g_state}, {"file_path": gc, "content": g_ai_bad}])
	# Kendi class_name'ine başvuran yeni betik (static factory, dönüş türü) geçer; yanlış üyesi geçmez.
	var g_self = "class_name TempClsGSelf\nextends RefCounted\nstatic func make() -> TempClsGSelf:\n\tvar d := TempClsGSelf.new()\n\treturn d\n"
	var g_self_ok = AISidebarVerificationPipeline.validate_batch_files([{"file_path": "res://tests/temp_cls_g_self.gd", "content": g_self}])
	var g_self_bad = AISidebarVerificationPipeline.validate_batch_files([{"file_path": "res://tests/temp_cls_g_self.gd", "content": g_self.replace(".new()", ".nope()")}])
	# Batch sınıfına başvuran betikte GERÇEK bir hata varsa model o hatayı görür, "Could not find type
	# <batch sınıfı>" değil (benchmark: world_map.gd'de her seferinde "Province bulunamadı" çıkıyordu).
	var g_map = "extends Node2D\nvar cells: Array[TempClsGData] = []\nfunc f() -> void:\n\tundefined_thing()\n"
	var g_real = AISidebarVerificationPipeline.validate_batch_files([{"file_path": ga, "content": g_data}, {"file_path": "res://tests/temp_cls_g_map.gd", "content": g_map}])
	var g_real_msg := str((g_real.get("error", {}) as Dictionary).get("message", ""))
	var real_reported: bool = not g_real.get("success", false) and g_real_msg.contains("undefined_thing") and not g_real_msg.contains("Could not find type")
	if not real_reported:
		errors.append("Test G: real error hidden: " + g_real_msg.left(200))
	# Diske yazılmış ama sınıf kaydına girmemiş class_name (benchmark: aynı adımda yazılan PlayerVisual).
	var disk_cls := "res://tests/temp_disk_cls.gd"
	var df := FileAccess.open(disk_cls, FileAccess.WRITE)
	df.store_string("class_name TempDiskCls\nextends RefCounted\nfunc size() -> int:\n\treturn 3\n")
	df.close()
	var use_ok = AISidebarVerificationPipeline.validate_batch_files([{"file_path": "res://tests/temp_use_disk.gd", "content": "extends Node\nvar v: TempDiskCls\nfunc f() -> int:\n\treturn TempDiskCls.new().size()\n"}])
	var use_bad = AISidebarVerificationPipeline.validate_batch_files([{"file_path": "res://tests/temp_use_disk.gd", "content": "extends Node\nfunc f() -> int:\n\treturn TempDiskCls.nope()\n"}])
	DirAccess.remove_absolute(disk_cls)
	var disk_ok: bool = use_ok.get("success", false) and not use_bad.get("success", false)
	if not disk_ok:
		errors.append("Test G: unregistered disk class: ok=%s bad=%s" % [str(use_ok.get("error", "")).left(160), use_bad.get("success")])
	# Kök neden öne alınır: bullet.gd yalnız enemy.gd bozuk olduğu için düşüyor; bildirilen hata enemy.gd'nin.
	var root_res = AISidebarVerificationPipeline.validate_batch_files([
		{"file_path": "res://tests/temp_root_bullet.gd", "content": "extends Area2D\nfunc hit(e: TempRootEnemy) -> void:\n\te.damage(1)\n"},
		{"file_path": "res://tests/temp_root_enemy.gd", "content": "class_name TempRootEnemy\nextends Node2D\nfunc damage(n: int) -> void:\n\tundefined_root_call(n)\n"}])
	var root_err: Dictionary = root_res.get("error", {}) if root_res.get("error") is Dictionary else {}
	var root_ok: bool = not root_res.get("success", false) and str(root_err.get("file_path", "")).ends_with("temp_root_enemy.gd") and str(root_err.get("message", "")).contains("undefined_root_call")
	if not root_ok:
		errors.append("Test G: root cause not reported: " + str(root_err.get("message", "")).left(200))
	if root_ok and disk_ok and real_reported and g_ok.get("success", false) and not g_bad.get("success", false) and g_self_ok.get("success", false) and not g_self_bad.get("success", false):
		passed += 1
	else:
		failed += 1
		errors.append("Test G Başarısız: batch class_name bağımlılığı: ok=" + str(g_ok) + " bad=" + str(g_bad.get("success")))

	# Temizlik
	for p in [path_a_gd, path_b_tscn, path_c_tscn, path_bad_gd]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

	return {"name": "DependencyAwareBatchTests", "passed": passed, "failed": failed, "errors": errors}
