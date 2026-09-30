class_name WeaponData
extends RefCounted
## Silah tanımları (veri). Yeni silah = yeni bir kayıt.

const WEAPONS: Array[Dictionary] = [
	{"name": "KAR98K", "damage": 70.0, "rate": 1.1, "clip": 5, "reserve": 40, "spread": 0.002, "auto": false, "reload": 2.4, "length": 0.72, "color": Color(0.32, 0.22, 0.14)},
	{"name": "MP40", "damage": 22.0, "rate": 0.09, "clip": 32, "reserve": 160, "spread": 0.02, "auto": true, "reload": 2.0, "length": 0.5, "color": Color(0.16, 0.17, 0.18)},
	{"name": "P08", "damage": 30.0, "rate": 0.32, "clip": 8, "reserve": 64, "spread": 0.01, "auto": false, "reload": 1.6, "length": 0.26, "color": Color(0.22, 0.22, 0.24)},
]

static func get_weapon(i: int) -> Dictionary:
	return WEAPONS[clampi(i, 0, WEAPONS.size() - 1)]
