extends Target

@export var hits_to_kill: int = 1
var _hits: int = 0


func take_hit(_from: Vector3, is_headshot: bool) -> void:
	_hits += 1
	var c := Palette.PRIMARY if is_headshot else Palette.ACCENT
	_flash(c)
	if _hits >= hits_to_kill:
		_topple()
