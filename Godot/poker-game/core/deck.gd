class_name Deck
extends RefCounted
## A standard 52-card deck.

var cards: Array[Card] = []


func _init() -> void:
	reset()


func reset() -> void:
	cards.clear()
	for suit in Card.Suit.values():
		for rank in range(1, 14):
			cards.append(Card.new(rank, suit))


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
