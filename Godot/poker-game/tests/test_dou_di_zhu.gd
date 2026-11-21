extends SceneTree
## Run: godot --headless --path . --script tests/test_dou_di_zhu.gd

const T := DouDiZhuCombo.Type

var failures := 0


func _init() -> void:
	GameSettings.save_to_disk = false  # never change the player's saved settings
	test_deck()
	test_combo_types()
	test_invalid_combos()
	test_beats()
	test_find_plays()
	test_bidding()
	test_scoring()
	test_ai()
	test_simulated_games()
	test_translations()
	print("FAILED: %d" % failures if failures > 0 else "ALL PASSED")
	quit(1 if failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", label)


## "3C 3D SJ BJ" -> cards. Suits default to clubs when left off ("3 3 3").
func hand(text: String) -> Array[Card]:
	var cards: Array[Card] = []
	var suit_cycle := 0
	for token in text.split(" "):
		if token == "SJ":
			cards.append(Card.new(Card.SMALL_JOKER, Card.Suit.CLUBS))
		elif token == "BJ":
			cards.append(Card.new(Card.BIG_JOKER, Card.Suit.HEARTS))
		else:
			var last := token.substr(token.length() - 1)
			var suit := Card.SUIT_NAMES.find(last)
			var rank_name := token
			if suit >= 0:
				rank_name = token.substr(0, token.length() - 1)
			else:
				suit = suit_cycle % 4  # different suits so equal ranks are distinct cards
				suit_cycle += 1
			cards.append(Card.new(Card.RANK_NAMES.find(rank_name), suit))
	return cards


func combo(text: String) -> DouDiZhuCombo:
	return DouDiZhuCombo.evaluate(hand(text))


func is_type(text: String, t: int) -> bool:
	var c := combo(text)
	return c != null and c.type == t


func test_deck() -> void:
	var deck := Deck.new(true)
	check(deck.cards.size() == 54, "deck with jokers has 54 cards")
	check(Deck.new().cards.size() == 52, "plain deck still has 52 cards")
	var order := hand("3 4 5 6 7 8 9 10 J Q K A 2 SJ BJ")
	for i in range(1, order.size()):
		check(DouDiZhuCombo.value(order[i]) > DouDiZhuCombo.value(order[i - 1]), "rank order at %s" % order[i])


func test_combo_types() -> void:
	check(is_type("7", T.SINGLE), "single")
	check(is_type("BJ", T.SINGLE), "joker single")
	check(is_type("8 8", T.PAIR), "pair")
	check(is_type("2 2 2", T.TRIPLE), "triple")
	check(is_type("J J J 4", T.TRIPLE_SINGLE), "triple + single")
	check(is_type("J J J 4 4", T.TRIPLE_PAIR), "triple + pair")
	check(is_type("3 4 5 6 7", T.STRAIGHT), "straight of 5")
	check(is_type("3 4 5 6 7 8 9 10 J Q K A", T.STRAIGHT), "straight 3 to A")
	check(is_type("3 3 4 4 5 5", T.PAIR_STRAIGHT), "three pairs in a row")
	check(is_type("6 6 6 7 7 7", T.AIRPLANE), "airplane")
	check(is_type("6 6 6 7 7 7 3 9", T.AIRPLANE_SINGLES), "airplane with single wings")
	check(is_type("6 6 6 7 7 7 3 3 9 9", T.AIRPLANE_PAIRS), "airplane with pair wings")
	check(is_type("9 9 9 9 3 K", T.FOUR_TWO_SINGLES), "four with two singles")
	check(is_type("9 9 9 9 3 3 K K", T.FOUR_TWO_PAIRS), "four with two pairs")
	check(is_type("5 5 5 5", T.BOMB), "bomb")
	check(is_type("SJ BJ", T.ROCKET), "rocket")
	var plane := combo("6 6 6 7 7 7 3 9")
	check(plane.main == 4 and plane.length == 2, "airplane main is its top triple")
	check(DouDiZhuCombo.value(plane.cards[0]) == 3, "main part is listed first")


func test_invalid_combos() -> void:
	check(combo("3 4") == null, "two different singles")
	check(combo("3 4 5 6") == null, "straight of 4")
	check(combo("J Q K A 2") == null, "straight with a 2")
	check(combo("10 J Q K A 2") == null, "long straight with a 2")
	check(combo("3 3 4 4") == null, "only two pairs in a row")
	check(combo("K K A A 2 2") == null, "pair run with 2s")
	check(combo("A A A 2 2 2") == null, "airplane with 2s")
	check(combo("6 6 6 8 8 8") == null, "triples not in a row")
	check(combo("6 6 6 7 7 7 3 3") == null, "wing singles must differ in rank")
	check(combo("6 6 6 7 7 7 SJ BJ") == null, "rocket can't be wings")
	check(combo("9 9 9 9 SJ BJ") == null, "rocket can't be four-with-two kickers")
	check(combo("J J J 4 5") == null, "triple with two different singles")


func test_beats() -> void:
	check(combo("8").beats(combo("7")), "higher single")
	check(not combo("7").beats(combo("8")), "lower single")
	check(combo("2").beats(combo("A")), "2 beats A")
	check(combo("SJ").beats(combo("2")), "small joker beats 2")
	check(combo("BJ").beats(combo("SJ")), "big joker beats small joker")
	check(not combo("3 3").beats(combo("K")), "pair can't beat single")
	check(combo("4 5 6 7 8").beats(combo("3 4 5 6 7")), "higher straight")
	check(not combo("4 5 6 7 8 9").beats(combo("3 4 5 6 7")), "straights must be the same length")
	check(combo("Q Q Q 3").beats(combo("J J J A")), "triple+single compares the triple only")
	check(combo("3 3 3 3").beats(combo("2 2")), "bomb beats a pair")
	check(combo("3 3 3 3").beats(combo("3 4 5 6 7 8 9 10 J Q K A")), "bomb beats a long straight")
	check(combo("4 4 4 4").beats(combo("3 3 3 3")), "higher bomb")
	check(not combo("3 3 3 3").beats(combo("4 4 4 4")), "lower bomb")
	check(combo("SJ BJ").beats(combo("2 2 2 2")), "rocket beats any bomb")
	check(not combo("2 2 2 2").beats(combo("SJ BJ")), "nothing beats the rocket")
	check(not combo("9 9 9 9 3 K").beats(combo("8")), "four-with-two is not a bomb")


func test_find_plays() -> void:
	var h := hand("3 3 3 4 4 4 5 6 7 8 9 9 9 9 SJ BJ")
	var plays := DouDiZhuRules.find_plays(h, null)
	var types := {}
	for p in plays:
		types[p.type] = true
		check(DouDiZhuCombo.evaluate(p.cards) != null, "listed play is valid")
	for t in [T.SINGLE, T.PAIR, T.TRIPLE, T.TRIPLE_SINGLE, T.TRIPLE_PAIR, T.STRAIGHT, T.AIRPLANE, T.AIRPLANE_SINGLES,
			T.FOUR_TWO_SINGLES, T.BOMB, T.ROCKET]:
		check(types.has(t), "find_plays lists type %d" % t)

	var to_beat := combo("K K")
	for p in DouDiZhuRules.find_plays(hand("3 3 A A 2 9 9 9 9"), to_beat):
		check(p.beats(to_beat), "following plays all beat the last play")
	var answers := DouDiZhuRules.find_plays(hand("3 3 A A 2 9 9 9 9"), to_beat)
	check(answers.size() == 2, "pair of A and the bomb answer K K (got %d)" % answers.size())


func test_bidding() -> void:
	var g := DouDiZhuGame.new()
	g.start(seeded(1))
	check(g.is_bidding(), "round starts with bidding")
	check(g.bottom.size() == 3, "three bottom cards")
	for p in 3:
		check(g.hand_of(p).size() == 17, "17 cards each")
	var first := g.current_player
	check(not g.bid((first + 1) % 3, 1), "only the current player may bid")
	check(g.bid(first, 1), "first bid")
	var second := g.current_player
	check(not g.bid(second, 1), "a bid must be higher")
	check(g.bid(second, 2), "raise to 2")
	var third := g.current_player
	check(g.bid(third, 0), "third passes")
	check(not g.is_bidding() and g.landlord == second, "highest bidder becomes landlord")
	check(g.hand_of(second).size() == 20, "landlord takes the bottom cards")
	check(g.current_player == second, "landlord leads")
	check(g.highest_bid == 2, "base score is the winning bid")

	var g3 := DouDiZhuGame.new()
	g3.start(seeded(2))
	check(g3.bid(g3.current_player, 3), "bid 3")
	check(not g3.is_bidding() and g3.landlord == g3.first_bidder, "bidding 3 ends at once")

	var g0 := DouDiZhuGame.new()
	g0.start(seeded(3))
	for i in 3:
		g0.bid(g0.current_player, 0)
	check(g0.needs_redeal and g0.landlord < 0, "nobody bids: redeal")


func test_scoring() -> void:
	var g := DouDiZhuGame.new()
	g.start(seeded(4))
	g.bid(g.current_player, 2)
	g.bid(g.current_player, 0)
	g.bid(g.current_player, 0)
	var lord := g.landlord
	# Farmers win with no bombs; the landlord played twice (no anti-spring).
	g.phase = DouDiZhuGame.Phase.OVER
	g.winner = (lord + 1) % 3
	g.plays_made.assign([2, 2, 2])
	var s := g.scores()
	check(s[lord] == -4 and s[(lord + 1) % 3] == 2 and s[(lord + 2) % 3] == 2, "farmers win 2 each")
	g.bomb_count = 2
	s = g.scores()
	check(s[lord] == -16, "two bombs multiply by 4")
	# Landlord wins by spring: farmers never played.
	g.bomb_count = 0
	g.winner = lord
	g.plays_made.assign([0, 0, 0])
	g.plays_made[lord] = 5
	check(g.is_spring(), "spring detected")
	s = g.scores()
	check(s[lord] == 8 and s[(lord + 1) % 3] == -4, "spring doubles the score")
	var sum := 0
	for v in s:
		sum += v
	check(sum == 0, "scores are zero-sum")


func test_ai() -> void:
	var g := DouDiZhuGame.new()
	g.start(seeded(5))
	g.hands[0] = hand("3 4 5 6 7 9 9 K")
	g.hands[1] = hand("8 8 Q")
	g.hands[2] = hand("A A")
	g.landlord = 0
	g.phase = DouDiZhuGame.Phase.PLAYING
	g.current_player = 0
	var lead := DouDiZhuAI.choose_play(g, 0)
	check(DouDiZhuCombo.evaluate(lead).type == T.STRAIGHT, "AI leads the low straight")

	# A farmer doesn't beat the other farmer.
	g.last_combo = combo("5")
	g.last_player = 1
	g.current_player = 2
	check(DouDiZhuAI.choose_play(g, 2).is_empty(), "farmer lets partner's play stand")
	# ...but always plays out when it can finish.
	g.last_combo = combo("K K")
	check(DouDiZhuAI.choose_play(g, 2).size() == 2, "farmer goes out when possible")

	var strong := hand("SJ BJ 2 2 2 A A K K Q Q J J 5 5 4 3")
	g.hands[1] = strong
	g.highest_bid = 0
	check(DouDiZhuAI.choose_bid(g, 1) == 3, "strong hand bids 3")
	g.hands[1] = hand("3 4 5 6 7 8 9 10 J Q 3 4 5 6 7 8 9")
	check(DouDiZhuAI.choose_bid(g, 1) == 0, "weak hand passes")


func test_simulated_games() -> void:
	for seed_value in 30:
		var g := DouDiZhuGame.new()
		var rng := seeded(seed_value)
		g.start(rng)
		var guard := 0
		while g.is_bidding() and guard < 20:
			if g.needs_redeal:
				g.start(rng)
			else:
				check(g.bid(g.current_player, DouDiZhuAI.choose_bid(g, g.current_player)), "AI bid accepted")
			guard += 1
		if g.is_bidding():
			continue
		var total := 0
		for p in 3:
			total += g.hand_of(p).size()
		check(total == 54, "all 54 cards in hands after bidding (seed %d)" % seed_value)
		var turns := 0
		while not g.is_over() and turns < 500:
			var p := g.current_player
			var cards := DouDiZhuAI.choose_play(g, p)
			var ok := g.pass_turn(p) if cards.is_empty() else g.play(p, cards)
			check(ok, "AI move accepted (seed %d)" % seed_value)
			if not ok:
				break
			turns += 1
		check(g.is_over(), "game finishes (seed %d)" % seed_value)
		var sum := 0
		for v in g.scores():
			sum += v
		check(sum == 0, "zero-sum scores (seed %d)" % seed_value)


func test_translations() -> void:
	for t in DouDiZhuCombo.Type.size():
		for locale in ["en", "zh_TW"]:
			check(I18n.TEXTS[locale].has("ddz_type_%d" % t), "%s names combo type %d" % [locale, t])


func seeded(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng
