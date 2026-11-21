extends Control
## 疊牌消消 screen: the stacked tiles in the middle, the 7-slot tray below.
## Click an uncovered tile to move it into the tray; three alike disappear.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const COUNTDOWN_SECONDS := 5
const RESULT_DELAY := 0.8

const FLY_TIME := 0.22
const CLEAR_TIME := 0.2
const AUTO_STEP := 0.09  # time per tile when finishing automatically
const SLOT_GAP := 8.0
const TRAY_PADDING := 12.0
const LAYER_LIFT := 4.0  # each layer is drawn a little higher, so stacked tiles show their edges

var game := TileStackGame.new()
var views: Dictionary = {}  # tile id -> TileView
var busy := false  # a pick is still settling (tile flying, match clearing)
var run_id := 0  # bumped on every new level so a stale countdown stops

var level_label: Label
var tiles_label: Label
var undo_button: Button
var finish_button: Button
var shuffle_button: Button
var menu_button: Button
var language_button: Button
var board_layer: Control
var tray_panel: Panel
var tray_layer: Control
var result_panel: ResultWindow


func _ready() -> void:
	_build_ui()
	resized.connect(_on_resized)
	_start_level(GameSettings.tile_level())


# --- Building the screen -----------------------------------------------------

func _build_ui() -> void:
	add_child(FeltBackground.new())

	level_label = _label(26)
	level_label.position = Vector2(20, 14)
	add_child(level_label)
	tiles_label = _label(18)
	tiles_label.position = Vector2(20, 50)
	add_child(tiles_label)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_row.position = Vector2(-680, 16)
	top_row.size = Vector2(660, 40)
	top_row.alignment = BoxContainer.ALIGNMENT_END
	add_child(top_row)
	finish_button = _button(top_row, _on_finish_pressed)
	finish_button.add_theme_color_override("font_color", ResultWindow.ACCENT)
	undo_button = _button(top_row, _on_undo_pressed)
	shuffle_button = _button(top_row, _on_shuffle_pressed)
	menu_button = _button(top_row, _go_to_menu)
	language_button = _button(top_row, _on_language_pressed)

	board_layer = Control.new()
	add_child(board_layer)

	tray_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.32, 0.2, 0.1, 0.92)  # wooden tray
	style.border_color = Color(0.55, 0.38, 0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	tray_panel.add_theme_stylebox_override("panel", style)
	tray_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray_panel)

	tray_layer = Control.new()
	tray_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray_layer)

	result_panel = ResultWindow.new()
	result_panel.menu_button.pressed.connect(_go_to_menu)
	result_panel.continue_button.pressed.connect(_on_continue_pressed)
	add_child(result_panel)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _button(row: Container, handler: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(110, 40)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(handler)
	row.add_child(button)
	return button


# --- Layout ------------------------------------------------------------------

func _slot_size() -> Vector2:
	return TileView.FACE + TileView.DEPTH


func _tray_rect() -> Rect2:
	var slot := _slot_size()
	var width := TileStackGame.TRAY_SIZE * slot.x + (TileStackGame.TRAY_SIZE - 1) * SLOT_GAP + TRAY_PADDING * 2
	var height := slot.y + TRAY_PADDING * 2
	return Rect2(Vector2((size.x - width) * 0.5, size.y - height - 18.0), Vector2(width, height))


func _slot_position(index: int) -> Vector2:
	var rect := _tray_rect()
	return rect.position + Vector2(TRAY_PADDING + index * (_slot_size().x + SLOT_GAP), TRAY_PADDING)


## Top-left pixel of a tile on the board, with the whole layout centred in the free area.
func _board_position(tile) -> Vector2:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for t in game.tiles:
		min_x = minf(min_x, t.x)
		max_x = maxf(max_x, t.x)
		min_y = minf(min_y, t.y)
		max_y = maxf(max_y, t.y)
	var face := TileView.FACE
	var board_size := Vector2((max_x - min_x + 1.0) * face.x, (max_y - min_y + 1.0) * face.y)
	var area_top := 84.0
	var area_bottom := _tray_rect().position.y - 16.0
	var origin := Vector2((size.x - board_size.x) * 0.5, area_top + (area_bottom - area_top - board_size.y) * 0.5)
	var lift: float = 0.0 if tile.in_pile else tile.z * LAYER_LIFT
	return origin + Vector2((tile.x - min_x) * face.x, (tile.y - min_y) * face.y - lift)


func _on_resized() -> void:
	_layout(0.0)


func _layout(duration: float) -> void:
	var rect := _tray_rect()
	tray_panel.position = rect.position
	tray_panel.size = rect.size
	result_panel.center_in(size)
	for t in game.tiles:
		var view: TileView = views[t.id]
		match t.state:
			TileStackGame.State.BOARD:
				_move(view, _board_position(t), duration)
			TileStackGame.State.TRAY:
				_move(view, _slot_position(game.tray.find(t)), duration)
	_refresh_board()


func _move(view: Control, target: Vector2, duration: float) -> void:
	if view.has_meta("tween"):
		var old: Tween = view.get_meta("tween")
		if old.is_valid():
			old.kill()
	if duration <= 0.0:
		view.position = target
		return
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "position", target, duration)
	view.set_meta("tween", tween)


# --- Level flow ----------------------------------------------------------------

func _start_level(level: int) -> void:
	run_id += 1
	busy = false
	result_panel.visible = false
	GameSettings.set_tile_level(level)
	game.start(level, TileFaces.kind_count())

	for child in board_layer.get_children():
		child.queue_free()
	for child in tray_layer.get_children():
		child.queue_free()
	views.clear()
	# Lower layers first so upper tiles are drawn on top.
	var ordered := game.tiles.duplicate()
	ordered.sort_custom(func(a, b) -> bool: return a.z < b.z if a.z != b.z else a.id < b.id)
	for t in ordered:
		var view := TileView.new()
		view.tile = t
		view.set_kind(t.kind)
		view.picked.connect(_on_tile_picked.bind(t))
		board_layer.add_child(view)
		views[t.id] = view
	_layout(0.0)
	# Tiles drop in from slightly above.
	for t in game.tiles:
		var view: TileView = views[t.id]
		var target := view.position
		view.position = target - Vector2(0, 30)
		view.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		var delay := 0.015 * t.z + 0.004 * t.id
		tween.tween_property(view, "position", target, 0.3).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(view, "modulate:a", 1.0, 0.25).set_delay(delay)
	Sfx.play_series("deal", 8, 0.05, -4.0)
	_refresh()


func _on_tile_picked(tile) -> void:
	if busy or not game.is_free(tile):
		return
	var slot := game.pick(tile)
	if slot < 0:
		return
	busy = true
	Sfx.play("select")
	var view: TileView = views[tile.id]
	view.reparent(tray_layer)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout(FLY_TIME)
	_refresh()

	var my_run := run_id
	await get_tree().create_timer(FLY_TIME).timeout
	if my_run != run_id:
		return
	var removed := game.resolve()
	if not removed.is_empty():
		Sfx.play("match")
		for t in removed:
			var gone: TileView = views[t.id]
			var tween := create_tween().set_parallel(true)
			tween.tween_property(gone, "scale", Vector2.ZERO, CLEAR_TIME)
			tween.tween_property(gone, "modulate:a", 0.0, CLEAR_TIME)
		await get_tree().create_timer(CLEAR_TIME).timeout
		if my_run != run_id:
			return
		_layout(FLY_TIME)
	busy = false
	_refresh()
	if game.is_over():
		_show_result()


## Picks the remaining tiles quickly, one after another, to finish the level.
func _on_finish_pressed() -> void:
	var plan := game.auto_finish_plan()
	if busy or plan.is_empty():
		return
	busy = true
	_refresh()
	var my_run := run_id
	for id in plan:
		var tile = game.tiles[id]
		game.pick(tile)
		var view: TileView = views[id]
		view.reparent(tray_layer)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Sfx.play("select", -6.0, 1.1)
		_layout(AUTO_STEP)
		await get_tree().create_timer(AUTO_STEP).timeout
		if my_run != run_id:
			return
		var removed := game.resolve()
		if not removed.is_empty():
			Sfx.play("match")
			for t in removed:
				var gone: TileView = views[t.id]
				var tween := create_tween().set_parallel(true)
				tween.tween_property(gone, "scale", Vector2.ZERO, CLEAR_TIME)
				tween.tween_property(gone, "modulate:a", 0.0, CLEAR_TIME)
			_layout(AUTO_STEP)
	busy = false
	_refresh()
	if game.is_over():
		_show_result()


func _on_undo_pressed() -> void:
	if busy or not game.undo():
		return
	Sfx.play("pass")
	_sync_views()
	_layout(FLY_TIME)
	_refresh()


func _on_shuffle_pressed() -> void:
	if busy or not game.shuffle():
		return
	Sfx.play_series("deal", 5, 0.05)
	for t in game.tiles:
		var view: TileView = views[t.id]
		view.set_kind(t.kind)
		if t.state == TileStackGame.State.BOARD:
			var tween := create_tween()
			tween.tween_property(view, "scale", Vector2(0.85, 0.85), 0.1)
			tween.tween_property(view, "scale", Vector2.ONE, 0.15)
	_refresh()


## Puts every view back in the layer, visibility and size its tile's state calls for (after undo).
func _sync_views() -> void:
	for t in game.tiles:
		var view: TileView = views[t.id]
		var in_tray: bool = t.state == TileStackGame.State.TRAY
		var parent := tray_layer if in_tray else board_layer
		if view.get_parent() != parent:
			view.reparent(parent)
		view.visible = t.state != TileStackGame.State.GONE
		view.scale = Vector2.ONE
		view.modulate.a = 1.0
	# Keep board tiles in drawing order (lower layers first).
	var board_views := board_layer.get_children()
	board_views.sort_custom(func(a, b) -> bool: return a.tile.z < b.tile.z if a.tile.z != b.tile.z else a.tile.id < b.tile.id)
	for i in board_views.size():
		board_layer.move_child(board_views[i], i)


func _on_language_pressed() -> void:
	I18n.toggle()
	_refresh()


func _go_to_menu() -> void:
	run_id += 1
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_continue_pressed() -> void:
	_start_level(game.level + 1 if game.is_won() else game.level)


func _show_result() -> void:
	var my_run := run_id
	var won := game.is_won()
	if won:
		GameSettings.unlock_tile_level(game.level + 1)
	await get_tree().create_timer(RESULT_DELAY).timeout
	if my_run != run_id:
		return
	Sfx.play("win" if won else "lose")
	result_panel.title_label.text = I18n.t("level_cleared" if won else "tray_full") % game.level
	result_panel.body_label.text = I18n.t("next_level_is") % (game.level + 1) if won else I18n.t("try_again_hint")
	result_panel.continue_button.text = I18n.t("next_level" if won else "retry")
	result_panel.menu_button.text = I18n.t("back_to_menu")
	result_panel.visible = true
	for left in range(COUNTDOWN_SECONDS, 0, -1):
		result_panel.countdown_label.text = I18n.t("countdown") % left
		result_panel.center_in(size)
		if left < COUNTDOWN_SECONDS:
			Sfx.play("tick", -4.0)
		await get_tree().create_timer(1.0).timeout
		if my_run != run_id:
			return
	_go_to_menu()


# --- Text and tile shading -------------------------------------------------------

func _refresh() -> void:
	level_label.text = I18n.t("level_n") % game.level
	tiles_label.text = I18n.t("tiles_left") % (game.board_count() + game.tray.size())
	undo_button.text = I18n.t("undo") % game.undo_left
	shuffle_button.text = I18n.t("shuffle") % game.shuffle_left
	menu_button.text = I18n.t("menu")
	language_button.text = I18n.t("language_button")
	undo_button.disabled = busy or not game.can_undo()
	finish_button.text = I18n.t("auto_finish")
	finish_button.visible = not busy and game.can_auto_finish()
	shuffle_button.disabled = busy or not game.can_shuffle()
	_refresh_board()


## Covered tiles are dimmed. Later levels dim them less, so they are harder to spot.
func _refresh_board() -> void:
	var shade: float = game.cover_shade
	for t in game.tiles:
		if t.state != TileStackGame.State.BOARD:
			continue
		var view: TileView = views[t.id]
		var free := game.is_free(t)
		view.self_modulate = Color.WHITE if free else Color(shade, shade, shade)
		view.mouse_filter = Control.MOUSE_FILTER_STOP if free else Control.MOUSE_FILTER_IGNORE
