class_name Level
extends RefCounted

const W := 60
const H := 20

# '1' solid, '2' hazard spikes, 'G' goal, 'P' player spawn, 'E' enemy patrol,
# 'C' coin, 'M' moving platform anchor
static func build() -> Dictionary:
	var solid := {}
	var hazards := {}
	var entities := []
	for x in range(W):
		solid[Vector2i(x, H - 1)] = true
		solid[Vector2i(x, H - 2)] = true
	var ground := [12, 22, 32, 41, 50]
	for gx in ground:
		for i in range(5):
			solid[Vector2i(gx + i, H - 6 - i)] = true
	# floating ledges
	var ledges := [
		Vector2i(5, 13), Vector2i(9, 10), Vector2i(15, 12),
		Vector2i(19, 9), Vector2i(26, 11), Vector2i(30, 8),
		Vector2i(35, 12), Vector2i(38, 8), Vector2i(45, 11),
		Vector2i(55, 13),
	]
	for l in ledges:
		for i in range(3):
			solid[l + Vector2i(i, 0)] = true
	# spikes on the floor in a few gaps
	for x in [16, 17, 43, 44]:
		hazards[Vector2i(x, H - 3)] = true
	# climbable wall block near the right end
	for i in range(4):
		solid[Vector2i(57, H - 3 - i)] = true
	entities.append({"type": "player", "tile": Vector2i(2, H - 4)})
	entities.append({"type": "goal", "tile": Vector2i(58, H - 7)})
	for t in [Vector2i(14, H - 3), Vector2i(25, H - 3), Vector2i(36, H - 3), Vector2i(48, H - 3)]:
		entities.append({"type": "enemy", "tile": t})
	for t in [
		Vector2i(6, 12), Vector2i(10, 9), Vector2i(20, 8), Vector2i(27, 10),
		Vector2i(31, 7), Vector2i(36, 11), Vector2i(46, 10), Vector2i(56, 12),
		Vector2i(8, H - 3), Vector2i(24, H - 3), Vector2i(40, H - 3), Vector2i(53, H - 3),
	]:
		entities.append({"type": "coin", "tile": t})
	entities.append({"type": "moving", "from": Vector2i(12, 10), "to": Vector2i(12, 5)})
	entities.append({"type": "moving", "from": Vector2i(31, 6), "to": Vector2i(31, 11)})
	entities.append({"type": "moving", "from": Vector2i(45, 9), "to": Vector2i(45, 4)})
	return {"solid": solid, "hazards": hazards, "entities": entities}
