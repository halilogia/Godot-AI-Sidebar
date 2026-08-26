extends Node

## Bilerek çalışma zamanı hatası üreten test betiği

func _ready() -> void:
	trigger_runtime_bug()

func trigger_runtime_bug() -> void:
	var invalid_obj: Variant = null
	var _crash_val = invalid_obj.get("speed")
