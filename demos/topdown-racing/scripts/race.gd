extends Node2D
class_name Race

const LAPS := 3

var cars: Array = []
var standings: Array = []
var finished := false

func _ready() -> void:
	standings = cars.duplicate()
	queue_redraw()

func _process(_d: float) -> void:
	if standings.size() != cars.size():
		standings = cars.duplicate()
	for c in cars:
		if c.finished:
			continue
		var t := fposmod(atan2(c.global_position.y / 470.0, c.global_position.x / 760.0) / TAU, 1.0)
		if t < c.last_t and c.last_t > 0.7:
			c.lap += 1
			if c.lap >= LAPS:
				c.finished = true
				c.place = cars.size()
		c.last_t = t
		c.progress = c.lap + t
	standings.sort_custom(func(a, b): return a.progress > b.progress)
	_place_changed()
	queue_redraw()

func _place_changed() -> void:
	for i in standings.size():
		standings[i].place = i + 1

func _draw() -> void:
	Track.draw(self, LAPS)
