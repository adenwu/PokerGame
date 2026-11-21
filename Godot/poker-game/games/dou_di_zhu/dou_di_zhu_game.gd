class_name DouDiZhuGame
extends RefCounted
## Turn-by-turn state of one Dou Di Zhu round (3 players). No UI: callers
## (scenes, AI, tests) drive it through bid(), play() and pass_turn().
##
## Rules used: 54 cards, 17 each and 3 bottom cards. A random player bids first;
## each player bids once (pass, or 1-3 points above the current bid), and a
## bid of 3 ends bidding at once. If nobody bids, the cards are redealt.
## The landlord takes (and shows) the bottom cards and leads. Score = bid ×
## 2^(bombs + rockets + spring), farmers each win/lose it, landlord twice.

enum Phase { BIDDING, PLAYING, OVER }

const PLAYER_COUNT := 3
const HAND_SIZE := 17
const MAX_BID := 3

var player_count := PLAYER_COUNT
var phase := Phase.BIDDING
var hands: Array = []  # Array of Array[Card]
var bottom: Array[Card] = []
var current_player := 0

var first_bidder := 0
var bids: Array[int] = []  # -1 not bid yet, 0 passed, else points
var highest_bid := 0
var highest_bidder := -1
var needs_redeal := false  # everyone passed: deal again
var landlord := -1

var last_combo: DouDiZhuCombo = null  # null means the current player leads a new round
var last_player := -1
var pass_count := 0
var winner := -1
var bomb_count := 0  # bombs and rockets played
var plays_made: Array[int] = []  # per player, for spring / anti-spring


func start(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var deck := Deck.new(true)
	deck.shuffle(rng)
	hands = deck.deal(PLAYER_COUNT, HAND_SIZE)
	bottom.assign(deck.cards)

	phase = Phase.BIDDING
	first_bidder = rng.randi_range(0, PLAYER_COUNT - 1)
	current_player = first_bidder
	bids.assign([-1, -1, -1])
	highest_bid = 0
	highest_bidder = -1
	needs_redeal = false
	landlord = -1
	last_combo = null
	last_player = -1
	pass_count = 0
	winner = -1
	bomb_count = 0
	plays_made.assign([0, 0, 0])


func is_over() -> bool:
	return phase == Phase.OVER


func is_bidding() -> bool:
	return phase == Phase.BIDDING


func hand_of(player: int) -> Array[Card]:
	return hands[player]


## Bid 0 to pass, or 1-3 points above the current highest bid.
func bid(player: int, points: int) -> bool:
	if phase != Phase.BIDDING or needs_redeal or player != current_player:
		return false
	if points != 0 and (points <= highest_bid or points > MAX_BID):
		return false
	bids[player] = points
	if points > 0:
		highest_bid = points
		highest_bidder = player
	var everyone_bid := not bids.has(-1)
	if points == MAX_BID or everyone_bid:
		_finish_bidding()
	else:
		current_player = (current_player + 1) % PLAYER_COUNT
	return true


func _finish_bidding() -> void:
	if highest_bidder < 0:
		needs_redeal = true
		return
	landlord = highest_bidder
	hands[landlord].append_array(bottom)
	current_player = landlord
	phase = Phase.PLAYING


## Plays cards for the current player. Returns false (and changes nothing) if the move is illegal.
func play(player: int, cards: Array) -> bool:
	if phase != Phase.PLAYING or player != current_player:
		return false
	var hand: Array[Card] = hands[player]
	for c in cards:
		if not hand.has(c):
			return false
	var combo := DouDiZhuCombo.evaluate(cards)
	if combo == null or (last_combo != null and not combo.beats(last_combo)):
		return false

	for c in cards:
		hand.erase(c)
	last_combo = combo
	last_player = player
	pass_count = 0
	plays_made[player] += 1
	if DouDiZhuCombo.is_bomb_type(combo.type):
		bomb_count += 1
	if hand.is_empty():
		winner = player
		phase = Phase.OVER
		return true
	current_player = (current_player + 1) % PLAYER_COUNT
	return true


## The player who leads a new round cannot pass.
func pass_turn(player: int) -> bool:
	if phase != Phase.PLAYING or player != current_player or last_combo == null:
		return false
	pass_count += 1
	if pass_count >= PLAYER_COUNT - 1:
		last_combo = null
		pass_count = 0
		current_player = last_player
	else:
		current_player = (current_player + 1) % PLAYER_COUNT
	return true


func is_farmer(player: int) -> bool:
	return landlord >= 0 and player != landlord


func landlord_won() -> bool:
	return winner == landlord


## 春天: the landlord wins before either farmer plays a card.
## 反春: the farmers win after the landlord played only the opening lead.
func is_spring() -> bool:
	if not is_over():
		return false
	if landlord_won():
		for p in PLAYER_COUNT:
			if p != landlord and plays_made[p] > 0:
				return false
		return true
	return plays_made[landlord] == 1


func multiplier() -> int:
	return 1 << (bomb_count + (1 if is_spring() else 0))


## Score change per player for a finished round.
func scores() -> Array[int]:
	var result: Array[int] = [0, 0, 0]
	if not is_over():
		return result
	var stake := highest_bid * multiplier()
	var farmer_sign := -1 if landlord_won() else 1
	for p in PLAYER_COUNT:
		if p == landlord:
			result[p] = -2 * farmer_sign * stake
		else:
			result[p] = farmer_sign * stake
	return result
