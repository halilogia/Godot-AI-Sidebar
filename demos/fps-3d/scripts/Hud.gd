extends Control

@onready var counter: Label = $Counter
@onready var bar: ProgressBar = $Bar


func _on_changed(collected: int, total: int) -> void:
	counter.text = "Toplanan: %d / %d" % [collected, total]
	bar.max_value = maxi(total, 1)
	bar.value = collected
	bar.visible = collected > 0 and collected < total
