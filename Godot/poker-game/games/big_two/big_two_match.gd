class_name BigTwoMatch
extends RefCounted
## A series of Big Two rounds with running totals. No UI: the table records
## each finished round's score changes here.

var player_count: int
var totals: Array[int] = []
var history: Array = []  # one Array[int] of score changes per finished round


func _init(p_player_count: int) -> void:
	player_count = p_player_count
	reset()


func reset() -> void:
	totals.resize(player_count)
	totals.fill(0)
	history.clear()


## Adds one finished round's score changes (as returned by BigTwoGame.scores()).
func record(scores: Array[int]) -> void:
	assert(scores.size() == player_count, "one score per player")
	for p in player_count:
		totals[p] += scores[p]
	history.append(scores.duplicate())


## The round currently being played, counting from 1.
func round_number() -> int:
	return history.size() + 1


## Score changes of the last finished round, or an empty array before the first one.
func last_round() -> Array[int]:
	var result: Array[int] = []
	if not history.is_empty():
		result.assign(history[-1])
	return result


## Player with the highest total, or -1 while nobody is strictly ahead.
func leader() -> int:
	var best := -1
	var tied := false
	for p in player_count:
		if best < 0 or totals[p] > totals[best]:
			best = p
			tied = false
		elif totals[p] == totals[best]:
			tied = true
	return -1 if tied else best
