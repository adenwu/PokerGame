class_name BigTwoGame
extends RefCounted
## Turn-by-turn state of one Big Two game for 3 or 4 players. No UI: callers
## (scenes, AI, tests) drive it through play() and pass_turn().

var player_count: int
var hands: Array = []  # Array of Array[Card], one per player
var current_player: int = 0
var last_combo: BigTwoCombo = null  # null means the current player leads a new round
var last_player: int = -1
var pass_count: int = 0
var winner: int = -1
var won_by_dragon: bool = false


func start(p_player_count: int, rng: RandomNumberGenerator = null) -> void:
	assert(p_player_count == 3 or p_player_count == 4, "Big Two supports 3 or 4 players")
	player_count = p_player_count
	last_combo = null
	last_player = -1
	pass_count = 0
	winner = -1
	won_by_dragon = false

	var deck := Deck.new()
	deck.shuffle(rng)
	hands = deck.deal(player_count, 13)
	current_player = _find_club_three_holder()
	if current_player < 0:
		# Only possible with 3 players: the club 3 is the leftover card, so a random seat gets it.
		current_player = (rng if rng != null else RandomNumberGenerator.new()).randi_range(0, player_count - 1)
	# With 3 players one card is left over; it goes face down to the club 3 holder.
	for leftover in deck.cards:
		hands[current_player].append(leftover)

	for p in player_count:
		if BigTwoRules.has_dragon(hands[p]):
			winner = p
			won_by_dragon = true
			return


func is_over() -> bool:
	return winner >= 0


func hand_of(player: int) -> Array[Card]:
	return hands[player]


## Plays cards for the current player. Returns false (and changes nothing) if the move is illegal.
func play(player: int, cards: Array) -> bool:
	if is_over() or player != current_player:
		return false
	var hand: Array[Card] = hands[player]
	for c in cards:
		if not hand.has(c):
			return false
	var combo := BigTwoCombo.evaluate(cards)
	if combo == null or cards.size() != combo.cards.size():
		return false
	if last_combo != null and not combo.beats(last_combo):
		return false

	for c in cards:
		hand.erase(c)
	last_combo = combo
	last_player = player
	pass_count = 0
	if hand.is_empty():
		winner = player
		return true
	_advance()
	return true


## The player who leads a new round cannot pass.
func pass_turn(player: int) -> bool:
	if is_over() or player != current_player or last_combo == null:
		return false
	pass_count += 1
	if pass_count >= player_count - 1:
		# Everyone else passed: the last player to play starts a fresh round.
		last_combo = null
		pass_count = 0
		current_player = last_player
	else:
		_advance()
	return true


func scores() -> Array[int]:
	return BigTwoRules.settle(hands, winner)


func _advance() -> void:
	current_player = (current_player + 1) % player_count


func _find_club_three_holder() -> int:
	for p in player_count:
		for c in hands[p]:
			if c.rank == 3 and c.suit == Card.Suit.CLUBS:
				return p
	return -1
