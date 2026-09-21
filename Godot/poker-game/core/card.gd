class_name Card
extends RefCounted
## One playing card. Rank is the natural rank (1 = A ... 13 = K); game rules
## decide how ranks and suits are ordered.

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }

const RANK_NAMES: Array[String] = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUIT_NAMES: Array[String] = ["C", "D", "H", "S"]

var rank: int
var suit: int


func _init(p_rank: int, p_suit: int) -> void:
	rank = p_rank
	suit = p_suit


func _to_string() -> String:
	return RANK_NAMES[rank] + SUIT_NAMES[suit]
