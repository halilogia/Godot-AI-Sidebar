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
		
	# Temizlik
	for p in [path_a_gd, path_b_tscn, path_c_tscn, path_bad_gd]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
			
	return {"name": "DependencyAwareBatchTests", "passed": passed, "failed": failed, "errors": errors}
