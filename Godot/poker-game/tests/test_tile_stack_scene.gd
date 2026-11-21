extends SceneTree
## Plays level 1 of 疊牌消消 on the real screen by clicking tiles.
## Run: godot --headless --path . --script tests/test_tile_stack_scene.gd

var failures := 0


func _initialize() -> void:
	GameSettings.save_to_disk = false  # never change the player's saved settings
	GameSettings.set_tile_level(1)
	var table: Control = load("res://scenes/tile_stack/tile_stack_table.tscn").instantiate()
	root.add_child(table)
	await create_timer(0.8).timeout

	var game: TileStackGame = table.game
	check(game.level == 1, "starts at level 1")
	check(table.views.size() == game.tiles.size(), "one view per tile")
	for t in game.tiles:
		var view: TileView = table.views[t.id]
		var free := game.is_free(t)
		if free:
			check(view.mouse_filter == Control.MOUSE_FILTER_STOP, "free tile is clickable")
		else:
			check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.self_modulate.r < 1.0, "covered tile is dimmed and not clickable")

	# Clicking a covered tile does nothing.
	for t in game.tiles:
		if not game.is_free(t):
			table._on_tile_picked(t)
			check(game.tray.is_empty(), "covered tile can't be picked")
			break

	# Undo once, then play the level through by its solution.
	var first: TileStackGame.Tile = game.tiles[game.solution[0]]
	table._on_tile_picked(first)
	await create_timer(0.6).timeout
	check(game.tray.size() == 1 and table.tray_layer.get_children().has(table.views[first.id]), "picked tile flies to the tray")
	table.undo_button.pressed.emit()
	await create_timer(0.4).timeout
	check(game.tray.is_empty() and first.state == TileStackGame.State.BOARD, "undo puts it back")
	check(table.undo_button.disabled, "undo used up")

	check(not table.finish_button.visible, "no finish button while tiles are stacked")
	for id in game.solution:
		if game.can_auto_finish():
			break
		table._on_tile_picked(game.tiles[id])
		var waited := 0.0
		while table.busy and waited < 2.0:
			await create_timer(0.05).timeout
			waited += 0.05
	check(table.finish_button.visible, "finish button appears once the board is flat")
	table.finish_button.pressed.emit()
	var finish_wait := 0.0
	while table.busy and finish_wait < 6.0:
		await create_timer(0.1).timeout
		finish_wait += 0.1
	check(game.is_won(), "level 1 cleared (finished in one go)")
	await create_timer(1.2).timeout
	check(table.result_panel.visible, "win window opens")
	check(GameSettings.tile_level_unlocked() >= 2, "level 2 unlocked")
	table.result_panel.continue_button.pressed.emit()
	await create_timer(0.6).timeout
	check(table.game.level == 2 and not table.result_panel.visible, "next level starts")

	# Losing: fill the tray with seven different kinds.
	var g: TileStackGame = table.game
	g.tray.clear()
	var used := {}
	for t in g.tiles:
		if g.tray.size() < 7 and not used.has(t.kind):
			used[t.kind] = true
			t.state = TileStackGame.State.TRAY
			g.tray.append(t)
	if g.tray.size() == 7:
		check(g.is_lost(), "full tray without a match loses")

	# The start screen offers a level choice for this game.
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.home_start_button.pressed.emit()
	menu.game_buttons[2].pressed.emit()
	check(menu.level_row.visible and not menu.count_row.visible, "level picker instead of player count")
	check(menu.level_value.text.contains("2"), "level picker shows the reached level")
	menu.level_prev.pressed.emit()
	check(GameSettings.tile_level() == 1, "can go back to level 1")
	check(menu.level_prev.disabled, "no level before 1")
	menu.level_next.pressed.emit()
	menu.level_next.pressed.emit()
	check(GameSettings.tile_level() == 2, "can't go past the highest unlocked level")

	print("FAILED: %d" % failures if failures > 0 else "ALL PASSED")
	quit(1 if failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", label)
