class_name CardData
extends RefCounted

## Destek kartları: 2..10, koz (suit) ve isim.
const SUITS := [
	{"suit": "Maça", "glyph": "♠", "color": Color("#f2eefb")},
	{"suit": "Karo", "glyph": "♦", "color": Color("#e0576b")},
	{"suit": "Tref", "glyph": "♣", "color": Color("#f2eefb")},
	{"suit": "Kupa", "glyph": "♥", "color": Color("#e0576b")},
]


static func build_deck() -> Array[Dictionary]:
	var deck: Array[Dictionary] = []
	for suit in SUITS:
		for rank in range(2, 11):
			deck.append({
				"rank": rank,
				"suit": suit["suit"],
				"glyph": suit["glyph"],
				"color": suit["color"],
			})
	return deck


static func label(card: Dictionary) -> String:
	return "%d%s" % [card["rank"], card["glyph"]]
