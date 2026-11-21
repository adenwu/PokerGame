class_name DouDiZhuAI
extends RefCounted
## Baseline Dou Di Zhu computer player.
## Bidding: counts strong cards (jokers, 2s, aces, bombs).
## Playing: sheds low cards in big combos, keeps bombs and jokers together,
## doesn't beat a fellow farmer, and only bombs when an opponent is close to winning.

const T := DouDiZhuCombo.Type
const DANGER_CARDS := 5  # an opponent with this many cards or fewer is worth bombing


static func choose_bid(game: DouDiZhuGame, player: int) -> int:
	var strength := hand_strength(game.hand_of(player))
	var wanted := 0
	if strength >= 8:
		wanted = 3
	elif strength >= 6:
		wanted = 2
	elif strength >= 4:
		wanted = 1
	return wanted if wanted > game.highest_bid else 0


static func hand_strength(hand: Array[Card]) -> float:
	var score := 0.0
	var counts := {}
	for c in hand:
		var v := DouDiZhuCombo.value(c)
		counts[v] = counts.get(v, 0) + 1
		match v:
			14:
				score += 3.0
			13:
				score += 2.0
			12:
				score += 1.5
			11:
				score += 0.5
	for v in counts:
		if counts[v] == 4:
			score += 3.0
	return score


## Returns the cards to play, or an empty array to pass.
static func choose_play(game: DouDiZhuGame, player: int) -> Array[Card]:
	var hand := game.hand_of(player)
	var plays := DouDiZhuRules.find_plays(hand, game.last_combo)
	if plays.is_empty():
		return []
	for combo in plays:
		if combo.cards.size() == hand.size():
			return combo.cards  # goes out: always take it

	var leading := game.last_combo == null
	if not leading and _same_side(game, player, game.last_player):
		return []  # let the partner's play stand

	var counts := {}
	for c in hand:
		var v := DouDiZhuCombo.value(c)
		counts[v] = counts.get(v, 0) + 1
	var normal: Array = plays.filter(func(c: DouDiZhuCombo) -> bool: return not DouDiZhuCombo.is_bomb_type(c.type))
	var keeps_bombs: Array = normal.filter(func(c: DouDiZhuCombo) -> bool: return not _breaks_bomb(c, counts))
	var danger := _opponent_in_danger(game, player)

	if leading:
		var pool := keeps_bombs if not keeps_bombs.is_empty() else (normal if not normal.is_empty() else plays)
		# Four-with-two spends a bomb; only lead it when nothing else is left.
		var no_fours: Array = pool.filter(func(c: DouDiZhuCombo) -> bool: return c.type != T.FOUR_TWO_SINGLES and c.type != T.FOUR_TWO_PAIRS)
		if not no_fours.is_empty():
			pool = no_fours
		pool.sort_custom(func(a: DouDiZhuCombo, b: DouDiZhuCombo) -> bool:
			if _lowest(a) != _lowest(b):
				return _lowest(a) < _lowest(b)  # get rid of low cards first
			if a.cards.size() != b.cards.size():
				return a.cards.size() > b.cards.size()  # in the biggest combo they fit in
			return _total(a) < _total(b)
		)
		return pool[0].cards

	var follow := keeps_bombs if not keeps_bombs.is_empty() else (normal if danger else [])
	if not follow.is_empty():
		follow.sort_custom(func(a: DouDiZhuCombo, b: DouDiZhuCombo) -> bool:
			if a.main != b.main:
				return a.main < b.main
			return _total(a) < _total(b)
		)
		return follow[0].cards
	if danger:
		var bombs: Array = plays.filter(func(c: DouDiZhuCombo) -> bool: return DouDiZhuCombo.is_bomb_type(c.type))
		if not bombs.is_empty():
			bombs.sort_custom(func(a: DouDiZhuCombo, b: DouDiZhuCombo) -> bool: return a.main < b.main)
			return bombs[0].cards
	return []


static func _same_side(game: DouDiZhuGame, a: int, b: int) -> bool:
	return a == b or (game.is_farmer(a) and game.is_farmer(b))


static func _opponent_in_danger(game: DouDiZhuGame, player: int) -> bool:
	for p in DouDiZhuGame.PLAYER_COUNT:
		if not _same_side(game, player, p) and game.hand_of(p).size() <= DANGER_CARDS:
			return true
	return false


## True when the combo uses part of a bomb (four of a kind) or one joker of the rocket.
static func _breaks_bomb(combo: DouDiZhuCombo, counts: Dictionary) -> bool:
	var used := {}
	for c in combo.cards:
		var v := DouDiZhuCombo.value(c)
		used[v] = used.get(v, 0) + 1
	for v in used:
		if counts[v] == 4 and used[v] < 4:
			return true
	var has_rocket: bool = counts.has(13) and counts.has(14)
	return has_rocket and (used.has(13) != used.has(14))


## Value of the lowest rank in the combo's main part (the bottom of a run).
static func _lowest(combo: DouDiZhuCombo) -> int:
	return combo.main - (combo.length - 1)


static func _total(combo: DouDiZhuCombo) -> int:
	var total := 0
	for c in combo.cards:
		total += DouDiZhuCombo.value(c)
	return total
