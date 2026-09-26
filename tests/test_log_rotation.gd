@tool
extends RefCounted

## Benchmark bulgusu: oyun print ettiği hâlde get_runtime_errors new_log_bytes: 0 dönüyordu. Oyun
## başlarken Godot godot.log'u yedekleyip boş bir dosya açar; okuma eski dosyanın uzunluğundan devam
## ettiği için yeni dosyanın başı (ilk print'ler, başlangıç hataları) kaçıyordu.

const AISidebarRuntimeDebugger = preload("res://addons/godot_sidebar_ai/core/runtime/runtime_debugger.gd")

const DIR := "user://ai_test_log_rotation"

static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []

	DirAccess.make_dir_recursive_absolute(DIR)
	_write(DIR + "/godot.log", "old run\n")
	_write(DIR + "/godot2026-01-01T10.00.00.log", "older run\n")
	_write(DIR + "/other.txt", "x")
	var before := AISidebarRuntimeDebugger.list_log_backups(DIR)
	var same := AISidebarRuntimeDebugger.rotated_since(before, AISidebarRuntimeDebugger.list_log_backups(DIR))
	# Oyun başladı: eski godot.log yedeklendi, yeni godot.log açıldı.
	_write(DIR + "/godot2026-01-01T10.05.00.log", "old run\n")
	_write(DIR + "/godot.log", "Godot Engine\nhello from game\n")
	var after := AISidebarRuntimeDebugger.list_log_backups(DIR)
	var rotated := AISidebarRuntimeDebugger.rotated_since(before, after)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + f)
	DirAccess.remove_absolute(DIR)

	if before == PackedStringArray(["godot2026-01-01T10.00.00.log"]) and not same and rotated and after.size() == 2:
		passed += 1
	else:
		failed += 1
		errors.append("T1 (rotation detection) failed: before=%s after=%s same=%s rotated=%s" % [str(before), str(after), str(same), str(rotated)])

	return {"name": "LogRotationTests", "passed": passed, "failed": failed, "errors": errors}
