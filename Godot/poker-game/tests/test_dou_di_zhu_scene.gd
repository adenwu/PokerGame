extends SceneTree
## Plays the start of a real Dou Di Zhu table: bid for landlord, take the
## bottom cards, play a card.
## Run: godot --headless --path . --script tests/test_dou_di_zhu_scene.gd

var failures := 0


func _initialize() -> void:
	GameSettings.save_to_disk = false  # never change the player's saved settings
	var table: Control = load("res://scenes/dou_di_zhu/dou_di_zhu_table.tscn").instantiate()
	root.add_child(table)
	await create_timer(0.8).timeout

	check(table.player_count == 3, "three seats")
	check(table.hand_views.size() == 17, "you get 17 cards")
	check(table.back_views[1].size() == 17 and table.back_views[2].size() == 17, "computer players get 17 cards")
	check(table.bottom_views.size() == 3, "three bottom cards on show")
	check(not table.play_button.visible, "no playing while bidding")

	# Wait for your bid (computer players may bid first; a 3 bid ends bidding early).
	var waited := 0.0
	while table.game.is_bidding() and table.game.current_player != 0 and waited < 10.0:
		await create_timer(0.2).timeout
		waited += 0.2
	if table.game.is_bidding():
		check(table.bid_buttons[0].visible and not table.bid_buttons[0].disabled, "no-bid button available")
		var highest: int = table.game.highest_bid
		if highest > 0:
			check(table.bid_buttons[highest].disabled, "can't bid the same as the highest bid")
		table.bid_buttons[3].pressed.emit()
		await create_timer(0.8).timeout
		check(table.game.landlord == 0, "bidding 3 makes you the landlord")
		check(table.hand_views.size() == 20, "landlord's hand shows 20 cards")
		check(table.bottom_views[0] is CardView, "bottom cards turned face up")
		check(table.play_button.visible and not table.bid_buttons[0].visible, "play buttons replace bid buttons")
		check(table.seat_labels[0].text.contains(I18n.t("landlord")), "your seat shows the landlord tag: %s" % table.seat_labels[0].text.c_escape())

		var lowest: Card = table.game.hand_of(0)[0]
		for c in table.game.hand_of(0):
			if DouDiZhuCombo.sort_key(c) < DouDiZhuCombo.sort_key(lowest):
				lowest = c
		table._on_card_pressed(lowest)
		table._on_play_pressed()
		await create_timer(0.6).timeout
		check(table.hand_views.size() == 19, "played card left the hand")
		check(table.table_views.size() == 1, "played card is on the table")
	else:
		check(table.game.landlord > 0, "a computer player took landlord with a 3 bid")

	# Let the computer players play on for a bit; the round must keep moving.
	await create_timer(4.0).timeout
	var cards_left := 0
	for p in 3:
		cards_left += table.game.hand_of(p).size()
	check(cards_left < 54 or table.game.is_bidding(), "cards are being played")

	# A finished round opens the result window with the landlord/farmer result.
	if not table.game.is_over():
		table.game.phase = DouDiZhuGame.Phase.OVER
		table.game.winner = table.game.landlord if table.game.landlord >= 0 else 0
		if table.game.landlord < 0:
			table.game.landlord = 0
			table.game.highest_bid = 1
	table._refresh()
	await create_timer(1.6).timeout
	check(table.result_panel.visible, "result window opens")
	var sum := 0
	for v in table.series.totals:
		sum += v
	check(sum == 0, "running totals stay zero-sum")

	print("FAILED: %d" % failures if failures > 0 else "ALL PASSED")
	quit(1 if failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", label)
