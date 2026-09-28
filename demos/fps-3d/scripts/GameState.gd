extends Node

var collected := 0
var total := 0

signal changed(collected: int, total: int)


func register_total() -> void:
	total = get_tree().get_nodes_in_group("collectibles").size()
	changed.emit(collected, total)


func collect() -> int:
	collected += 1
	changed.emit(collected, total)
	return collected


func reset() -> void:
	collected = 0
	changed.emit(collected, total)
