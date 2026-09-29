class_name Board
extends RefCounted

const SIZE := 8

var cells: Array[Array] = []  # cells[y][x] -> int gem type, -1 empty


func _init() -> void:
	for y in SIZE:
		var row: Array[int] = []
		for x in SIZE:
			row.append(-1)
		cells.append(row)


func get_gem(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return -1
	return cells[y][x]


func set_gem(x: int, y: int, type: int) -> void:
	cells[y][x] = type


func fill_random(rng: RandomNumberGenerator) -> void:
	for y in SIZE:
		for x in SIZE:
			var t := 0
			while true:
				t = rng.randi() % Palette.GEM_COLORS.size()
				set_gem(x, y, t)
				if _match_at(x, y).is_empty():
					break


## Cells that are part of a run of 3 or more.
func find_matches() -> Array[Vector2i]:
	var found: Dictionary = {}
	for y in SIZE:
		var run: Array[Vector2i] = []
		for x in range(SIZE + 1):
			if x < SIZE and get_gem(x, y) >= 0 and (run.is_empty() or get_gem(x, y) == get_gem(run[0].x, run[0].y)):
				run.append(Vector2i(x, y))
			else:
				if run.size() >= 3:
					for c in run:
						found[c] = true
				run = []
				if x < SIZE and get_gem(x, y) >= 0:
					run = [Vector2i(x, y)]
	for x in SIZE:
		var run2: Array[Vector2i] = []
		for y in range(SIZE + 1):
			if y < SIZE and get_gem(x, y) >= 0 and (run2.is_empty() or get_gem(x, y) == get_gem(run2[0].x, run2[0].y)):
				run2.append(Vector2i(x, y))
			else:
				if run2.size() >= 3:
					for c in run2:
						found[c] = true
				run2 = []
				if y < SIZE and get_gem(x, y) >= 0:
					run2 = [Vector2i(x, y)]
	var out: Array[Vector2i] = []
	for c in found.keys():
		out.append(c)
	return out


func _match_at(x: int, y: int) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	var t := get_gem(x, y)
	if t < 0:
		return res
	var run := 0
	for i in range(x, -1, -1):
		if get_gem(i, y) == t:
			run += 1
		else:
			break
	for i in range(x + 1, SIZE):
		if get_gem(i, y) == t:
			run += 1
		else:
			break
	if run >= 3:
		for i in range(x - run + 1, x + run):
			res.append(Vector2i(i, y))
	run = 0
	for i in range(y, -1, -1):
		if get_gem(x, i) == t:
			run += 1
		else:
			break
	for i in range(y + 1, SIZE):
		if get_gem(x, i) == t:
			run += 1
		else:
			break
	if run >= 3:
		for i in range(y - run + 1, y + run):
			res.append(Vector2i(x, i))
	return res


func swap(a: Vector2i, b: Vector2i) -> void:
	var t := get_gem(a.x, a.y)
	set_gem(a.x, a.y, get_gem(b.x, b.y))
	set_gem(b.x, b.y, t)


func has_valid_move() -> bool:
	for y in SIZE:
		for x in SIZE:
			if x + 1 < SIZE:
				swap(Vector2i(x, y), Vector2i(x + 1, y))
				var ok := not find_matches().is_empty()
				swap(Vector2i(x, y), Vector2i(x + 1, y))
				if ok:
					return true
			if y + 1 < SIZE:
				swap(Vector2i(x, y), Vector2i(x, y + 1))
				var ok2 := not find_matches().is_empty()
				swap(Vector2i(x, y), Vector2i(x, y + 1))
				if ok2:
					return true
	return false


## Returns { "moves": {from: to}, "spawns": {column: count} } and empties the cells
## that need fresh gems, so they can be spawned with a chosen type.
func apply_gravity() -> Dictionary:
	var moves: Dictionary = {}
	var spawns: Dictionary = {}
	for x in SIZE:
		var write_y := SIZE - 1
		for y in range(SIZE - 1, -1, -1):
			if get_gem(x, y) >= 0:
				if write_y != y:
					set_gem(x, write_y, get_gem(x, y))
					set_gem(x, y, -1)
					moves[Vector2i(x, y)] = Vector2i(x, write_y)
				write_y -= 1
		var missing := write_y + 1
		if missing > 0:
			spawns[x] = missing
			for y in range(missing):
				set_gem(x, y, -1)
	return {"moves": moves, "spawns": spawns}
