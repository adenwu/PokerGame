class_name BigTwoCombo
extends RefCounted
## A valid Big Two play (single, pair or five-card hand) with a comparable key.

# Ordered weakest to strongest; five-card hands compare by this order first.
enum Type { SINGLE, PAIR, STRAIGHT, FLUSH, FULL_HOUSE, FOUR_OF_A_KIND, STRAIGHT_FLUSH }

const TYPE_NAMES: Array[String] = ["single", "pair", "straight", "flush", "full house", "four of a kind", "straight flush"]

var type: int
var cards: Array[Card] = []
## Compared element by element, larger wins. Only meaningful between combos of the same type.
var key: Array[int] = []


## 3 is lowest (0), 2 is highest (12). Suits keep Card.Suit order (clubs lowest, spades highest).
static func rank_value(card: Card) -> int:
	return (card.rank + 10) % 13


static func strength(card: Card) -> int:
	return rank_value(card) * 4 + card.suit


## Returns null when the cards are not a valid combo.
static func evaluate(p_cards: Array) -> BigTwoCombo:
	var sorted: Array[Card] = []
	sorted.assign(p_cards)
	sorted.sort_custom(func(a: Card, b: Card) -> bool: return strength(a) < strength(b))

	var combo := BigTwoCombo.new()
	combo.cards = sorted
	match sorted.size():
		1:
			combo.type = Type.SINGLE
			combo.key = [strength(sorted[0])]
			return combo
		2:
			if sorted[0].rank != sorted[1].rank:
				return null
			combo.type = Type.PAIR
			combo.key = [strength(sorted[1])]
			return combo
		5:
			return combo if combo._classify_five() else null
	return null


func _classify_five() -> bool:
	var counts := {}
	var is_flush := true
	for c in cards:
		counts[c.rank] = counts.get(c.rank, 0) + 1
		if c.suit != cards[0].suit:
			is_flush = false
	var order := _straight_order()
	var top := cards[4]

	if order >= 0 and is_flush:
		type = Type.STRAIGHT_FLUSH
		key = [order, strength(top)]
	elif counts.size() == 2:
		# Four of a kind or full house: the repeated rank decides.
		var big_rank := 0
		for r in counts:
			if counts[r] >= 3:
				big_rank = r
		var big_card: Card = cards.filter(func(c: Card) -> bool: return c.rank == big_rank)[0]
		type = Type.FOUR_OF_A_KIND if counts[big_rank] == 4 else Type.FULL_HOUSE
		key = [rank_value(big_card)]
	elif is_flush:
		type = Type.FLUSH
		key = []
		for i in range(4, -1, -1):
			key.append(rank_value(cards[i]))
		key.append(cards[0].suit)
	elif order >= 0:
		type = Type.STRAIGHT
		key = [order, strength(top)]
	else:
		return false
	return true


## Straight strength order, or -1 when not a straight. 3-7 is 0 ... 10-A is 7,
## A-5 is 8, 2-6 is 9. J-Q-K-A-2 and other wrap-arounds are not straights.
func _straight_order() -> int:
	var mask := 0
	for c in cards:
		mask |= 1 << c.rank
	for start in range(1, 11):
		var expected := 0
		for i in 5:
			expected |= 1 << ((start - 1 + i) % 13 + 1)
		if expected == mask:
			if start == 1:
				return 8
			if start == 2:
				return 9
			return start - 3
	return -1


## 1 if this beats other, -1 if it loses, 0 if equal. Both must have the same card count.
func compare(other: BigTwoCombo) -> int:
	if type != other.type:
		return 1 if type > other.type else -1
	for i in key.size():
		if key[i] != other.key[i]:
			return 1 if key[i] > other.key[i] else -1
	return 0


func beats(other: BigTwoCombo) -> bool:
	return cards.size() == other.cards.size() and compare(other) > 0


func _to_string() -> String:
	return "%s %s" % [TYPE_NAMES[type], cards]
