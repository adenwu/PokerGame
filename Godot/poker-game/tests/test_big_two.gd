extends SceneTree
## Run: godot --headless --path . --script tests/test_big_two.gd

var failures := 0


func _init() -> void:
	test_card_order()
	test_combos()
	test_straight_order()
	test_five_card_order()
	test_rules()
	test_simulated_games()
	print("FAILED: %d" % failures if failures > 0 else "ALL PASSED")
	quit(1 if failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", label)


func hand(text: String) -> Array[Card]:
	var cards: Array[Card] = []
	for token in text.split(" "):
		var suit_char := token.substr(token.length() - 1)
		var rank_name := token.substr(0, token.length() - 1)
		cards.append(Card.new(Card.RANK_NAMES.find(rank_name), Card.SUIT_NAMES.find(suit_char)))
	return cards


func combo(text: String) -> BigTwoCombo:
	return BigTwoCombo.evaluate(hand(text))


func test_card_order() -> void:
	var s2 := hand("2S")[0]
	var c3 := hand("3C")[0]
	check(BigTwoCombo.strength(s2) == 51, "2S is the strongest card")
	check(BigTwoCombo.strength(c3) == 0, "3C is the weakest card")
	check(BigTwoCombo.strength(hand("AC")[0]) < BigTwoCombo.strength(hand("2C")[0]), "2 beats A")
	check(combo("3S").beats(combo("3H")), "spades beat hearts")
	check(combo("3H").beats(combo("3D")), "hearts beat diamonds")
	check(combo("3D").beats(combo("3C")), "diamonds beat clubs")


func test_combos() -> void:
	check(combo("3C 3D") != null, "pair is valid")
	check(combo("3C 4D") == null, "mismatched two cards invalid")
	check(combo("3C 3D 3H") == null, "triple is not a play")
	check(combo("3S 3C").beats(combo("3H 3D")), "pair compares highest suit")
	check(not combo("3S 3C").beats(combo("4C 5C 6C 7C 9C")), "different sizes never beat")
	check(not combo("3S").beats(combo("3S 3C")), "single cannot beat pair")


func test_straight_order() -> void:
	var s_2_6 := combo("2C 3D 4H 5S 6C")
	var s_a_5 := combo("AC 2D 3H 4S 5C")
	var s_10_a := combo("10C JD QH KS AC")
	var s_9_k := combo("9C 10D JH QS KC")
	var s_3_7 := combo("3C 4D 5H 6S 7C")
	check(s_2_6.type == BigTwoCombo.Type.STRAIGHT, "23456 is a straight")
	check(s_2_6.beats(s_a_5), "23456 > A2345")
	check(s_a_5.beats(s_10_a), "A2345 > 10JQKA")
	check(s_10_a.beats(s_9_k), "10JQKA > 9-K")
	check(s_9_k.beats(s_3_7), "9-K > 3-7")
	check(combo("JC QD KH AS 2C") == null, "JQKA2 is not a straight")
	check(combo("QC KD AH 2S 3C") == null, "QKA23 is not a straight")
	check(combo("3C 4D 5H 6S 7S").beats(combo("3C 4D 5H 6S 7C")), "same straight compares top suit")


func test_five_card_order() -> void:
	var straight := combo("3C 4D 5H 6S 7C")
	var flush := combo("3H 6H 9H JH KH")
	var full_house := combo("3C 3D 3H 4S 4C")
	var four := combo("3C 3D 3H 3S 4C")
	var straight_flush := combo("3H 4H 5H 6H 7H")
	check(flush.type == BigTwoCombo.Type.FLUSH, "flush detected")
	check(full_house.type == BigTwoCombo.Type.FULL_HOUSE, "full house detected")
	check(four.type == BigTwoCombo.Type.FOUR_OF_A_KIND, "four of a kind detected")
	check(straight_flush.type == BigTwoCombo.Type.STRAIGHT_FLUSH, "straight flush detected")
	# Five-card hands must match the type being beaten; only the bombs cross types.
	check(not flush.beats(straight), "flush cannot beat a straight")
	check(not straight.beats(flush), "straight cannot beat a flush")
	check(not full_house.beats(flush), "full house cannot beat a flush")
	check(not full_house.beats(straight), "full house cannot beat a straight")
	check(four.beats(straight), "four beats a straight")
	check(four.beats(flush), "four beats a flush")
	check(four.beats(full_house), "four beats a full house")
	check(straight_flush.beats(straight), "straight flush beats a straight")
	check(straight_flush.beats(full_house), "straight flush beats a full house")
	check(straight_flush.beats(four), "straight flush beats four")
	check(not four.beats(straight_flush), "four cannot beat a straight flush")
	check(combo("6C 6D 6H 6S 3C").beats(combo("5C 5D 5H 5S KC")), "four compares the repeated rank")
	check(not combo("5C 5D 5H 5S KC").beats(combo("6C 6D 6H 6S 3C")), "lower four loses")
	check(combo("4H 5H 6H 7H 8H").beats(combo("3H 4H 5H 6H 7H")), "straight flush compares like a straight")
	check(combo("2C 3C 4C 5C 6C").beats(combo("AD 2D 3D 4D 5D")), "23456 flush beats A2345 flush")
	check(not combo("4C 5C 6C 7C 9C").beats(combo("6C 7D 8H 9S 10C")), "flush cannot beat a straight")
	check(not combo("6C 7D 8H 9S 10C").beats(combo("4C 5C 6C 7C 9C")), "straight cannot beat a flush")
	check(not combo("4C 4D 4H 3S 3C").beats(combo("6C 7D 8H 9S 10C")), "full house cannot beat a straight")
	check(combo("JC QD KH AS 10C").beats(combo("6C 7D 8H 9S 10C")) == true, "higher straight beats lower straight")
	check(combo("4C 4D 4H 3S 3C").beats(combo("3C 3D 3H 2S 2C")), "full house compares triple rank")
	check(combo("3C 5C 7C 9C KC").beats(combo("3D 5D 7D 9D QD")), "flush compares top rank")
	check(combo("4C 5C 7C 9C KC").beats(combo("3D 5D 7D 9D KD")) == true, "flush compares second-tier ranks in order")
	check(combo("3S 5S 7S 9S KS").beats(combo("3C 5C 7C 9C KC")), "equal-rank flush compares suit")
	check(combo("3C 4D 5H 6S 8C") == null, "non-straight five cards invalid")


func test_rules() -> void:
	check(BigTwoRules.has_dragon(hand("AC 2C 3C 4C 5C 6C 7C 8C 9C 10C JC QC KC")), "dragon detected")
	check(not BigTwoRules.has_dragon(hand("AC AD 3C 4C 5C 6C 7C 8C 9C 10C JC QC KC")), "no dragon with a duplicate rank")
	check(BigTwoRules.penalty(hand("3C 4C 5C")) == 30, "3 cards left costs 30")
	check(BigTwoRules.penalty(hand("3C 2C 5C")) == 60, "holding a 2 doubles the penalty")
	var eleven := hand("3C 4C 5C 6C 7C 8C 9C 10C JC QC KC")
	check(BigTwoRules.penalty(eleven) == 220, "more than 10 cards doubles the penalty")
	var plays := BigTwoRules.find_plays(hand("3C 3D 4C 5H 9S"), combo("4D"))
	check(plays.size() == 2 and plays.all(func(c: BigTwoCombo) -> bool: return c.cards.size() == 1), "only bigger singles beat a single")


func test_simulated_games() -> void:
	for seed_value in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var players := 3 + seed_value % 2
		var game := BigTwoGame.new()
		game.start(players, rng)

		var total := 0
		for p in players:
			total += game.hand_of(p).size()
		check(total == 52, "all 52 cards dealt (seed %d)" % seed_value)
		if game.won_by_dragon:
			continue

		var turns := 0
		while not game.is_over() and turns < 2000:
			var player := game.current_player
			var cards := BigTwoAI.choose_play(game, player)
			var ok := game.pass_turn(player) if cards.is_empty() else game.play(player, cards)
			check(ok, "AI move accepted (seed %d)" % seed_value)
			if not ok:
				break
			turns += 1
		check(game.is_over(), "game finishes (seed %d)" % seed_value)
		if game.is_over():
			check(game.hand_of(game.winner).is_empty(), "winner has no cards (seed %d)" % seed_value)
			var scores := game.scores()
			check(scores.reduce(func(a: int, b: int) -> int: return a + b, 0) == 0, "scores sum to zero (seed %d)" % seed_value)
