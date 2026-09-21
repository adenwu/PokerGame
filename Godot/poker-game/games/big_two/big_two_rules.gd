class_name BigTwoRules
extends RefCounted
## Stateless helpers for Taiwan Big Two: finding plays, dragon check, scoring.


## Every valid combo (singles, pairs, five-card hands) that can be formed from the hand.
static func find_combos(hand: Array[Card]) -> Array[BigTwoCombo]:
	var combos: Array[BigTwoCombo] = []
	var n := hand.size()
	for i in n:
		combos.append(BigTwoCombo.evaluate([hand[i]]))
		for j in range(i + 1, n):
			var pair := BigTwoCombo.evaluate([hand[i], hand[j]])
			if pair != null:
				combos.append(pair)
	for a in n:
		for b in range(a + 1, n):
			for c in range(b + 1, n):
				for d in range(c + 1, n):
					for e in range(d + 1, n):
						var five := BigTwoCombo.evaluate([hand[a], hand[b], hand[c], hand[d], hand[e]])
						if five != null:
							combos.append(five)
	return combos


## Combos playable right now: anything when leading (last is null), otherwise only ones that beat last.
static func find_plays(hand: Array[Card], last: BigTwoCombo) -> Array[BigTwoCombo]:
	var combos := find_combos(hand)
	if last == null:
		return combos
	return combos.filter(func(c: BigTwoCombo) -> bool: return c.beats(last))


## "一條龍": all 13 ranks present, which wins the game immediately.
static func has_dragon(hand: Array[Card]) -> bool:
	var ranks := {}
	for c in hand:
		ranks[c.rank] = true
	return ranks.size() == 13


## Points a losing hand costs: 10 per card left, doubled with more than 10 cards or any 2.
static func penalty(hand: Array[Card]) -> int:
	var points := hand.size() * 10
	if hand.size() > 10 or hand.any(func(c: Card) -> bool: return c.rank == 2):
		points *= 2
	return points


## Score change for each player: losers pay their penalty, the winner collects it all.
static func settle(hands: Array, winner: int) -> Array[int]:
	var scores: Array[int] = []
	scores.resize(hands.size())
	scores.fill(0)
	for p in hands.size():
		if p == winner:
			continue
		var cost := penalty(hands[p])
		scores[p] -= cost
		scores[winner] += cost
	return scores
