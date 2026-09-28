class_name GameRules
extends RefCounted

## Basit "savaş" (war) tarzı kural seti: oyuncu 5 el kartı ile
## bilgisayarın 5 kartına karşı oynar, en yüksek kart eler.

static func compare(player: Dictionary, opponent: Dictionary) -> int:
	if player["value"] > opponent["value"]:
		return 1
	if player["value"] < opponent["value"]:
		return -1
	return 0
