extends SceneTree
## Plays the first turns of a real table scene (select, play, animate).
## Run: godot --headless --path . --script tests/test_table_scene.gd

var failures := 0


func _initialize() -> void:
	GameSettings._player_count = 4  # don't depend on (or overwrite) the saved choice
	var table: Control = load("res://scenes/big_two/big_two_table.tscn").instantiate()
	root.add_child(table)
	await create_timer(1.0).timeout  # let the deal animation finish

	check(table.hand_views.size() == table.game.hand_of(0).size(), "hand views match the hand")
	for seat in range(1, 4):
		check(table.back_views[seat].size() == table.game.hand_of(seat).size(), "seat %d has one back per card" % seat)

	# Wait for the human's turn (computer players may lead first).
	var waited := 0.0
	while table.game.current_player != 0 and waited < 10.0:
		await create_timer(0.2).timeout
		waited += 0.2
	check(table.game.current_player == 0, "human turn reached")

	var plays := BigTwoRules.find_plays(table.game.hand_of(0), table.game.last_combo)
	if plays.is_empty():
		check(not table.pass_button.disabled or table.game.last_combo == null, "pass allowed when nothing can be played")
		table._on_pass_pressed()
	else:
		var combo: BigTwoCombo = plays[0]
		var hand_before: int = table.game.hand_of(0).size()
		var resting: Dictionary = {}
		for card in combo.cards:
			resting[card] = table.hand_views[card].position
			table._on_card_pressed(card)
		await create_timer(0.4).timeout
		var lifted := 0
		for card in combo.cards:
			var view: Control = table.hand_views[card]
			if view.position.distance_to(resting[card]) > table.SELECT_LIFT * 0.8:
				lifted += 1
		check(lifted == combo.cards.size(), "picked-up cards moved (animation ran)")

		table._on_play_pressed()
		await create_timer(0.8).timeout
		check(table.game.hand_of(0).size() == hand_before - combo.cards.size(), "cards left the hand")
		check(table.hand_views.size() == table.game.hand_of(0).size(), "hand views updated")
		check(table.table_views.size() >= combo.cards.size(), "cards are on the table")
		for view in table.table_views:
			var center: Vector2 = view.position + view.size * 0.5
			check(center.distance_to(table._table_center()) < 300.0, "played card is near the table center")

	# Let the computer players take a few turns, then switch language and start over.
	await create_timer(3.0).timeout
	I18n.toggle()
	table._refresh()
	check(not table.status_label.text.is_empty(), "status text present after language switch")
	table._start_game()
	await create_timer(0.8).timeout
	check(table.hand_views.size() == table.game.hand_of(0).size(), "new game deals a fresh hand")

	# Finishing a round records it once and opens the result window.
	table.game.winner = 1
	table._refresh()
	table._refresh()
	check(table.series.history.size() == 1, "finished round recorded exactly once")
	check(not table.play_button.visible, "play button hidden after the round")
	await create_timer(1.6).timeout
	check(table.result_panel.visible, "result window opens after the round")
	check(table.countdown_label.text.contains("4") or table.countdown_label.text.contains("5"), "countdown is running")

	# Continue keeps the totals, closes the window and stops the countdown.
	var totals_after: Array[int] = table.series.totals.duplicate()
	table.continue_button.pressed.emit()
	await create_timer(0.8).timeout
	check(not table.result_panel.visible, "continue closes the result window")
	check(table.series.totals == totals_after, "next round keeps the totals")
	check(table.series.round_number() == 2, "round counter advanced")
	table._start_game()
	check(table.series.history.is_empty(), "new game clears the totals")

	# Without pressing anything, the countdown returns to the start screen.
	table.game.winner = 2
	table._refresh()
	await create_timer(table.RESULT_DELAY + table.COUNTDOWN_SECONDS + 1.0).timeout
	check(current_scene != null and current_scene.name == "MainMenu", "countdown returns to the start screen")
	table.queue_free()

	# The start screen: home -> game list -> Big Two options.
	var menu: Control = current_scene
	check(menu.home_page.visible and not menu.game_page.visible, "start screen begins at home")
	menu.home_start_button.pressed.emit()
	check(menu.game_page.visible and not menu.home_page.visible, "start opens the game list")
	menu.game_buttons[0].pressed.emit()
	check(menu.options_page.visible and not menu.game_page.visible, "choosing a game shows the player count")
	menu.back_button.pressed.emit()
	check(menu.game_page.visible, "back returns to the game list")
	menu.back_button.pressed.emit()
	check(menu.home_page.visible, "back again returns home")

	# A 3-player table seats the computer players right and left.
	GameSettings._player_count = 3
	var small: Control = load("res://scenes/big_two/big_two_table.tscn").instantiate()
	root.add_child(small)
	await create_timer(1.0).timeout
	check(small.game.player_count == 3, "3-player game started")
	check(small.back_views.size() == 3, "two computer fans")
	check(small._seat_name(2) == I18n.t("seat_3"), "third player sits on the left")
	check(small.hand_views.size() == small.game.hand_of(0).size(), "your 3-player hand is drawn")
	check(small.back_views[1].size() == small.game.hand_of(1).size() and small.back_views[2].size() == small.game.hand_of(2).size(), "3-player fans match the hands")

	print("FAILED: %d" % failures if failures > 0 else "ALL PASSED")
	quit(1 if failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", label)
