class_name DouDiZhuCombo
extends RefCounted
## A valid Dou Di Zhu play. Suits never matter; only rank values do.
## A combo beats another of the same type and size with a higher `main`;
## a bomb beats any non-bomb, and the rocket (both jokers) beats everything.

enum Type {
	SINGLE, PAIR, TRIPLE, TRIPLE_SINGLE, TRIPLE_PAIR,
	STRAIGHT, PAIR_STRAIGHT, AIRPLANE, AIRPLANE_SINGLES, AIRPLANE_PAIRS,
	FOUR_TWO_SINGLES, FOUR_TWO_PAIRS, BOMB, ROCKET,
}

const HIGHEST_IN_RUN := 11  # runs (straights, pair runs, airplanes) stop at A: no 2s, no jokers

var type: int
var cards: Array[Card] = []  # main part first (e.g. the triples), then the kickers
var main := 0  # value of the highest card of the main part
var length := 1  # number of ranks in the main run (1 for non-runs)


## 3 is 0 ... K is 10, A is 11, 2 is 12, small joker 13, big joker 14.
static func value(card: Card) -> int:
	match card.rank:
		1:
			return 11
		2:
			return 12
		Card.SMALL_JOKER:
			return 13
		Card.BIG_JOKER:
			return 14
	return card.rank - 3


## Hand order: by value, then suit.
static func sort_key(card: Card) -> int:
	return value(card) * 4 + card.suit


static func is_bomb_type(t: int) -> bool:
	return t == Type.BOMB or t == Type.ROCKET


func beats(other: DouDiZhuCombo) -> bool:
	if type == Type.ROCKET:
		return true
	if other.type == Type.ROCKET:
		return false
	if type == Type.BOMB:
		return other.type != Type.BOMB or main > other.main
	if other.type == Type.BOMB:
		return false
	return type == other.type and cards.size() == other.cards.size() and length == other.length and main > other.main


## Returns null when the cards are not a valid combo.
static func evaluate(p_cards: Array) -> DouDiZhuCombo:
	var n := p_cards.size()
	if n == 0:
		return null
	var counts := {}  # value -> number of cards
	for c in p_cards:
		var v := value(c)
		counts[v] = counts.get(v, 0) + 1
	var values: Array = counts.keys()
	values.sort()

	if n == 2 and counts.has(13) and counts.has(14):
		return _make(p_cards, Type.ROCKET, 14, 1, [14])
	if n == 1:
		return _make(p_cards, Type.SINGLE, values[0], 1, values)
	if values.size() == 1:
		match n:
			2:
				return _make(p_cards, Type.PAIR, values[0], 1, values)
			3:
				return _make(p_cards, Type.TRIPLE, values[0], 1, values)
			4:
				return _make(p_cards, Type.BOMB, values[0], 1, values)
		return null

	var with_count := func(k: int) -> Array:
		return values.filter(func(v: int) -> bool: return counts[v] == k)

	# Triple with one kicker card or one kicker pair.
	if n == 4 and with_count.call(3).size() == 1:
		return _make(p_cards, Type.TRIPLE_SINGLE, with_count.call(3)[0], 1, with_count.call(3))
	if n == 5 and with_count.call(3).size() == 1 and with_count.call(2).size() == 1:
		return _make(p_cards, Type.TRIPLE_PAIR, with_count.call(3)[0], 1, with_count.call(3))

	# Runs made of one count only.
	for spec in [[1, 5, Type.STRAIGHT], [2, 3, Type.PAIR_STRAIGHT], [3, 2, Type.AIRPLANE]]:
		var per: int = spec[0]
		if with_count.call(per).size() == values.size() and values.size() >= spec[1] and _is_run(values):
			return _make(p_cards, spec[2], values[-1], values.size(), values)

	# Four with two single cards (any two, but not the rocket) or with two pairs.
	var fours: Array = with_count.call(4)
	if fours.size() == 1:
		if n == 6 and not (counts.has(13) and counts.has(14)):
			return _make(p_cards, Type.FOUR_TWO_SINGLES, fours[0], 1, fours)
		if n == 8 and with_count.call(2).size() == 2:
			return _make(p_cards, Type.FOUR_TWO_PAIRS, fours[0], 1, fours)

	# Airplane with wings: k consecutive triples plus k single cards or k pairs.
	for wing_size in [1, 2]:
		if n % (3 + wing_size) != 0:
			continue
		var k: int = n / (3 + wing_size)
		if k < 2:
			continue
		var run := _wing_run(counts, values, k, wing_size)
		if not run.is_empty():
			var t := Type.AIRPLANE_SINGLES if wing_size == 1 else Type.AIRPLANE_PAIRS
			return _make(p_cards, t, run[-1], k, run)
	return null


static func _is_run(values: Array) -> bool:
	if values[-1] > HIGHEST_IN_RUN:
		return false
	for i in range(1, values.size()):
		if values[i] != values[i - 1] + 1:
			return false
	return true


## Finds k consecutive triples whose leftover cards form k wings of `wing_size`
## cards each, all of different ranks and none of the triples' ranks.
static func _wing_run(counts: Dictionary, values: Array, k: int, wing_size: int) -> Array:
	var triples: Array = values.filter(func(v: int) -> bool: return counts[v] >= 3 and v <= HIGHEST_IN_RUN)
	for start_index in range(triples.size() - k, -1, -1):
		var run: Array = triples.slice(start_index, start_index + k)
		if not _is_run(run):
			continue
		var ok := true
		var wings := 0
		for v in values:
			var left: int = counts[v] - (3 if run.has(v) else 0)
			if left == 0:
				continue
			if run.has(v) or left != wing_size:
				ok = false
				break
			wings += 1
		if ok and wings == k and not (wing_size == 1 and counts.has(13) and counts.has(14)):
			return run
	return []


## Builds the combo with the cards of `main_values` first, then the kickers.
static func _make(p_cards: Array, p_type: int, p_main: int, p_length: int, main_values: Array) -> DouDiZhuCombo:
	var combo := DouDiZhuCombo.new()
	combo.type = p_type
	combo.main = p_main
	combo.length = p_length
	var sorted: Array[Card] = []
	sorted.assign(p_cards)
	sorted.sort_custom(func(a: Card, b: Card) -> bool:
		var a_main := main_values.has(value(a))
		var b_main := main_values.has(value(b))
		if a_main != b_main:
			return a_main
		return sort_key(a) < sort_key(b)
	)
	combo.cards = sorted
	return combo
