class_name Deck
extends RefCounted
## A standard 52-card deck, optionally with the two jokers (54 cards).

const SIZE := 52

var cards: Array[Card] = []
var with_jokers := false


func _init(p_with_jokers: bool = false) -> void:
	with_jokers = p_with_jokers
	reset()


func reset() -> void:
	cards.clear()
	for suit in Card.Suit.values():
		for rank in range(1, 14):
			cards.append(Card.new(rank, suit))
	if with_jokers:
		cards.append(Card.new(Card.SMALL_JOKER, Card.Suit.CLUBS))
		cards.append(Card.new(Card.BIG_JOKER, Card.Suit.HEARTS))


func shuffle(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


## Deals cards one at a time around the table until every player has
## hand_size cards. Undealt cards stay in `cards`. Returns Array of Array[Card].
func deal(player_count: int, hand_size: int) -> Array:
	var hands: Array = []
	for p in player_count:
		var hand: Array[Card] = []
		hands.append(hand)
	for i in hand_size:
		for p in player_count:
			hands[p].append(cards.pop_back())
	return hands
