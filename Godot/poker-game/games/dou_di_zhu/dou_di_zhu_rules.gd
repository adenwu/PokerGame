class_name DouDiZhuRules
extends RefCounted
## Stateless helpers for Dou Di Zhu: listing every play a hand can make.

const T := DouDiZhuCombo.Type


## Every legal combo in the hand that can be played now: anything when leading
## (last is null), otherwise only combos that beat `last`.
static func find_plays(hand: Array[Card], last: DouDiZhuCombo) -> Array[DouDiZhuCombo]:
	var by_value := _group(hand)
	var values: Array = by_value.keys()
	values.sort()
	var candidates: Array = []  # Array of Array[Card]
	var want := -1 if last == null or DouDiZhuCombo.is_bomb_type(last.type) else last.type

	var take := func(v: int, k: int) -> Array: return by_value[v].slice(0, k)
	var allows := func(t: int) -> bool: return want < 0 or want == t

	for v in values:
		var count: int = by_value[v].size()
		if allows.call(T.SINGLE):
			candidates.append(take.call(v, 1))
		if count >= 2 and allows.call(T.PAIR):
			candidates.append(take.call(v, 2))
		if count >= 3:
			if allows.call(T.TRIPLE):
				candidates.append(take.call(v, 3))
			for other in values:
				if other == v:
					continue
				if allows.call(T.TRIPLE_SINGLE):
					candidates.append(take.call(v, 3) + take.call(other, 1))
				if by_value[other].size() >= 2 and allows.call(T.TRIPLE_PAIR):
					candidates.append(take.call(v, 3) + take.call(other, 2))
		if count == 4:
			candidates.append(take.call(v, 4))  # bomb: always worth listing
			var others: Array = values.filter(func(o: int) -> bool: return o != v)
			if allows.call(T.FOUR_TWO_SINGLES):
				for pick in _choose(others, 2):
					candidates.append(take.call(v, 4) + take.call(pick[0], 1) + take.call(pick[1], 1))
				for o in others:
					if by_value[o].size() >= 2:
						candidates.append(take.call(v, 4) + take.call(o, 2))
			if allows.call(T.FOUR_TWO_PAIRS):
				var pairs: Array = others.filter(func(o: int) -> bool: return by_value[o].size() >= 2)
				for pick in _choose(pairs, 2):
					candidates.append(take.call(v, 4) + take.call(pick[0], 2) + take.call(pick[1], 2))
	if by_value.has(13) and by_value.has(14):
		candidates.append(take.call(13, 1) + take.call(14, 1))

	# Runs: straights (5+ singles), pair runs (3+ pairs), airplanes (2+ triples) with optional wings.
	for spec in [[1, 5, T.STRAIGHT], [2, 3, T.PAIR_STRAIGHT], [3, 2, T.AIRPLANE]]:
		var per: int = spec[0]
		var min_len: int = spec[1]
		for start in range(0, DouDiZhuCombo.HIGHEST_IN_RUN + 1):
			var run: Array = []
			for v in range(start, DouDiZhuCombo.HIGHEST_IN_RUN + 1):
				if by_value.get(v, []).size() < per:
					break
				run.append(v)
				if run.size() < min_len:
					continue
				var base: Array = []
				for r in run:
					base += take.call(r, per)
				if allows.call(spec[2]):
					candidates.append(base)
				if per == 3 and run.size() <= 5:
					_add_wings(candidates, base, run, values, by_value, allows)

	var plays: Array[DouDiZhuCombo] = []
	var seen := {}
	for cards in candidates:
		var combo := DouDiZhuCombo.evaluate(cards)
		if combo == null or (last != null and not combo.beats(last)):
			continue
		var id := str(combo.cards)
		if seen.has(id):
			continue
		seen[id] = true
		plays.append(combo)
	return plays


static func _add_wings(candidates: Array, base: Array, run: Array, values: Array, by_value: Dictionary, allows: Callable) -> void:
	var k := run.size()
	var others: Array = values.filter(func(o: int) -> bool: return not run.has(o))
	if allows.call(T.AIRPLANE_SINGLES):
		for pick in _choose(others, k):
			if pick.has(13) and pick.has(14):
				continue
			var cards: Array = base.duplicate()
			for o in pick:
				cards.append(by_value[o][0])
			candidates.append(cards)
	if allows.call(T.AIRPLANE_PAIRS):
		var pairs: Array = others.filter(func(o: int) -> bool: return by_value[o].size() >= 2)
		for pick in _choose(pairs, k):
			var cards: Array = base.duplicate()
			for o in pick:
				cards += by_value[o].slice(0, 2)
			candidates.append(cards)


## Cards grouped by value, each group in suit order.
static func _group(hand: Array) -> Dictionary:
	var by_value := {}
	for c in hand:
		var v := DouDiZhuCombo.value(c)
		if not by_value.has(v):
			by_value[v] = []
		by_value[v].append(c)
	for v in by_value:
		by_value[v].sort_custom(func(a: Card, b: Card) -> bool: return a.suit < b.suit)
	return by_value


## All k-element subsets of `items` (as arrays, in order).
static func _choose(items: Array, k: int) -> Array:
	var result: Array = []
	if k == 0:
		result.append([])
		return result
	for i in range(items.size() - k + 1):
		for rest in _choose(items.slice(i + 1), k - 1):
			result.append([items[i]] + rest)
	return result
