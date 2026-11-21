class_name Card
extends RefCounted
## One playing card. Rank is the natural rank (1 = A ... 13 = K), or 14/15 for
## the small/big joker; game rules decide how ranks and suits are ordered.
## Jokers use CLUBS (small, drawn black) and HEARTS (big, drawn red) as their suit.

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }

const SMALL_JOKER := 14
const BIG_JOKER := 15
const RANK_NAMES: Array[String] = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "SJ", "BJ"]
const SUIT_NAMES: Array[String] = ["C", "D", "H", "S"]

var rank: int
var suit: int


func _init(p_rank: int, p_suit: int) -> void:
	rank = p_rank
	suit = p_suit


func is_joker() -> bool:
	return rank >= SMALL_JOKER


func _to_string() -> String:
	return RANK_NAMES[rank] if is_joker() else RANK_NAMES[rank] + SUIT_NAMES[suit]
