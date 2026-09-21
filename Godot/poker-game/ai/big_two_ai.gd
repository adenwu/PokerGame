class_name BigTwoAI
extends RefCounted
## Baseline Big Two computer player: plays the weakest legal combo, and when
## leading prefers to shed five-card hands first. Meant as the "easy" level.


## Returns the cards to play, or an empty array to pass.
static func choose_play(game: BigTwoGame, player: int) -> Array[Card]:
	var plays := BigTwoRules.find_plays(game.hand_of(player), game.last_combo)
	if plays.is_empty():
		return []

	var leading := game.last_combo == null
	plays.sort_custom(func(a: BigTwoCombo, b: BigTwoCombo) -> bool:
		if leading and a.cards.size() != b.cards.size():
			return a.cards.size() > b.cards.size()
		if a.type != b.type:
			return a.type < b.type
		return a.compare(b) < 0
	)
	return plays[0].cards
