extends SceneTree
## Plays the first turns of a real table scene (select, play, animate).
## Run: godot --headless --path . --script tests/test_table_scene.gd

var failures := 0


func _initialize() -> void:
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
		for card in combo.cards:
			table._on_card_pressed(card)
		await create_timer(0.4).timeout
		var lifted := 0
		for card in combo.cards:
			var view: Control = table.hand_views[card]
			if view.position.y < table.size.y - 200.0:
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

	print("FAILED: %d" % failures if failures > 0 else "ALL PASSED")
	quit(1 if failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", label)
