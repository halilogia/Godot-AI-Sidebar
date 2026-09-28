class_name CardData
extends RefCounted

enum Suit { HEARTS, DIAMONDS, CLUBS, SPADES }

const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

static func make(rank_index: int, suit: int) -> Dictionary:
	return {
		"rank": RANKS[rank_index],
		"value": rank_index + 1,
		"suit": suit,
		"red": suit == Suit.HEARTS or suit == Suit.DIAMONDS,
	}

static func make_deck() -> Array[Dictionary]:
	var deck: Array[Dictionary] = []
	for s in Suit.values():
		for r in RANKS.size():
			deck.append(make(r, s))
	return deck

static func describe(card: Dictionary) -> String:
	return "%s %s" % [card["rank"], Suit.keys()[card["suit"]]]

static func suit_symbol(suit: int) -> String:
	return ["♥", "♦", "♣", "♠"][suit]

static func suit_name(suit: int) -> String:
	return ["Kupa", "Karo", "Sinek", "Maça"][suit]
