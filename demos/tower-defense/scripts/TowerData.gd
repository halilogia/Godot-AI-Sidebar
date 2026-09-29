class_name TowerData
extends RefCounted

enum Kind { ARCHER, CANNON, FROST }

const DEFS := {
	Kind.ARCHER: {
		"kind": Kind.ARCHER,
		"name": "Okçu",
		"cost": 90,
		"range": 210.0,
		"damage": 12.0,
		"cooldown": 0.7,
		"slow": false,
	},
	Kind.CANNON: {
		"name": "Top",
		"cost": 140,
		"range": 170.0,
		"damage": 30.0,
		"cooldown": 1.5,
		"slow": false,
	},
	Kind.FROST: {
		"name": "Buz",
		"cost": 120,
		"range": 150.0,
		"damage": 6.0,
		"cooldown": 1.1,
		"slow": true,
	},
}
