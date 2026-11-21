extends CardTable
## Big Two table for 3 or 4 players (chosen on the start screen).


func _setup_game() -> void:
	game = BigTwoGame.new()
	player_count = GameSettings.player_count()


func _deal_round() -> void:
	game.start(player_count)
	if game.is_over():
		_set_action("act_dragon", [_seat_name(game.winner)])


func _card_order(card: Card) -> int:
	return BigTwoCombo.strength(card)


func _combo_name(combo) -> String:
	return I18n.t("type_%d" % combo.type)


func _ai_choose_play(player: int) -> Array[Card]:
	return BigTwoAI.choose_play(game, player)
