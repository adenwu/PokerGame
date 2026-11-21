class_name CardTable
extends Control
## Shared card-table screen for shedding games (Big Two, Dou Di Zhu): you sit at
## the bottom and the computer players take turns counterclockwise (right, top,
## left; with 3 players only right and left). Every hand is drawn as a fan.
##
## A game's table extends this and fills in the hooks in the "Game hooks"
## section. `game` must offer: start state via _deal_round(), is_over(),
## current_player, hand_of(p), last_combo (with .cards), last_player,
## play(p, cards), pass_turn(p), scores(), winner.

const HUMAN := 0
const AI_DELAY := 0.9
const MENU_SCENE := "res://scenes/main_menu.tscn"
const RESULT_DELAY := 1.2  # time to see the winning play before the result window opens
const COUNTDOWN_SECONDS := 5

const CARD_SIZE := Vector2(76, 108)
const BACK_SIZE := Vector2(50, 72)
const TABLE_SCALE := 0.8
const TABLE_STEP := 62.0

# Fan geometry: cards sit on a circle of `radius`; spacing is the arc length between cards.
const HAND_RADIUS := 1300.0
const HAND_SPACING := 50.0
const OPPONENT_RADIUS := 420.0
const OPPONENT_SPACING := 20.0
# Longest a fan may get (arc length); bigger hands (17-20 cards) are squeezed to fit.
const HAND_MAX_SPAN := 620.0
const OPPONENT_MAX_SPAN := 240.0
const SELECT_LIFT := 34.0

const MOVE_TIME := 0.25
const FLY_TIME := 0.35
const DEAL_STAGGER := 0.03
const ACTIVE_COLOR := Color(1.0, 0.9, 0.3)

# Screen slots: 0 bottom, 1 right, 2 top, 3 left. Players map onto them by player count.
const SLOTS_BY_COUNT := {3: [0, 1, 3], 4: [0, 1, 2, 3]}
# Direction each slot's cards face (toward the table center), in radians.
const SEAT_FACING: Array[float] = [0.0, -PI / 2.0, PI, PI / 2.0]

var game  # the rules object; see the class comment
var player_count := 4
var series: ScoreSeries
var round_recorded := false  # the finished round's scores were added to `series`
var selected: Array[Card] = []
var last_action_key := ""
var last_action_args: Array = []
var run_id := 0  # bumped on every new round so a stale AI loop or countdown stops itself

var hand_views: Dictionary = {}  # Card -> CardView, your hand
var back_views: Array = []  # per seat: Array of CardBackView (index 0 unused)
var table_views: Array = []  # cards currently shown in the middle

var seat_labels: Array[Label] = []
var last_play_label: Label
var status_label: Label
var scoreboard_label: Label
var button_row: HBoxContainer
var play_button: Button
var pass_button: Button
var menu_button: Button
var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var countdown_label: Label
var continue_button: Button
var result_menu_button: Button
var language_button: Button
var hand_layer: Control
var table_layer: Control


func _ready() -> void:
	_setup_game()
	series = ScoreSeries.new(player_count)
	_build_ui()
	resized.connect(_on_resized)
	_start_game()


# --- Game hooks (override in each game's table) ------------------------------

## Creates `game` and sets `player_count`.
func _setup_game() -> void:
	pass


## Shuffles and deals a new round in `game` (no UI work).
func _deal_round() -> void:
	pass


## Sort key for your hand, weakest first.
func _card_order(card: Card) -> int:
	return card.rank * 4 + card.suit


## Short name of a combo for the "who played what" line.
func _combo_name(_combo) -> String:
	return ""


## Cards a computer player plays now, or an empty array to pass.
func _ai_choose_play(_player: int) -> Array[Card]:
	return []


## One computer move. Override to add other kinds of moves (e.g. bidding).
func _ai_step(player: int) -> void:
	var cards := _ai_choose_play(player)
	if cards.is_empty():
		game.pass_turn(player)
		_set_action("act_passed", [_seat_name(player)])
	else:
		game.play(player, cards)
		_ai_play_animation(player, game.last_combo.cards)
		_set_action("act_played", [_seat_name(player)])


## True while the current turn is about playing cards (not, say, bidding).
func _in_play_phase() -> bool:
	return not game.is_over()


## Text under a seat's name (default: cards left).
func _seat_text(player: int) -> String:
	return "%s\n%s" % [_seat_name(player), I18n.t("cards_left") % game.hand_of(player).size()]


## Hint shown on your turn, or the "thinking" line otherwise.
func _turn_hint(my_turn: bool) -> String:
	if my_turn:
		return I18n.t("hint_lead" if game.last_combo == null else "hint_beat")
	return I18n.t("thinking") % _seat_name(game.current_player)


## Called after every refresh so a table can update its own widgets.
func _refresh_extra() -> void:
	pass


func _result_headline() -> String:
	return I18n.t("win_you") if game.winner == HUMAN else I18n.t("win_other") % _seat_name(game.winner)


# --- Building the screen -----------------------------------------------------

func _build_ui() -> void:
	add_child(FeltBackground.new())

	for i in player_count:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		label.size = Vector2(150, 60)
		add_child(label)
		seat_labels.append(label)

	last_play_label = Label.new()
	last_play_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	last_play_label.add_theme_font_size_override("font_size", 20)
	add_child(last_play_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 22)
	add_child(status_label)

	button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	add_child(button_row)
	play_button = _make_button(_on_play_pressed)
	pass_button = _make_button(_on_pass_pressed)
	menu_button = _make_button(_go_to_menu)

	scoreboard_label = Label.new()
	scoreboard_label.add_theme_font_size_override("font_size", 18)
	scoreboard_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	scoreboard_label.add_theme_constant_override("outline_size", 4)
	scoreboard_label.position = Vector2(16, 12)
	add_child(scoreboard_label)

	language_button = Button.new()
	language_button.custom_minimum_size = Vector2(110, 40)
	language_button.add_theme_font_size_override("font_size", 18)
	language_button.pressed.connect(_on_language_pressed)
	add_child(language_button)

	hand_layer = Control.new()
	add_child(hand_layer)
	table_layer = Control.new()
	table_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(table_layer)

	_build_result_panel()


## The window that opens when a round ends: result, continue, or back to the start screen.
func _build_result_panel() -> void:
	result_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.12, 0.08)
	style.border_color = ACTIVE_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	result_panel.add_theme_stylebox_override("panel", style)
	result_panel.visible = false
	add_child(result_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	result_panel.add_child(column)

	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 34)
	result_title.add_theme_color_override("font_color", ACTIVE_COLOR)
	column.add_child(result_title)

	result_body = Label.new()
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_body.add_theme_font_size_override("font_size", 22)
	column.add_child(result_body)

	countdown_label = Label.new()
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 18)
	countdown_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	column.add_child(countdown_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	continue_button = Button.new()
	continue_button.custom_minimum_size = Vector2(150, 48)
	continue_button.add_theme_font_size_override("font_size", 22)
	continue_button.pressed.connect(_start_round)
	row.add_child(continue_button)
	result_menu_button = Button.new()
	result_menu_button.custom_minimum_size = Vector2(170, 48)
	result_menu_button.add_theme_font_size_override("font_size", 22)
	result_menu_button.pressed.connect(_go_to_menu)
	row.add_child(result_menu_button)


func _make_button(handler: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(130, 44)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(handler)
	button_row.add_child(button)
	return button


# --- Layout -----------------------------------------------------------------

func _slot(player: int) -> int:
	return SLOTS_BY_COUNT[player_count][player]


func _seat_name(player: int) -> String:
	return I18n.t("seat_%d" % _slot(player))


func _seat_anchor(seat: int) -> Vector2:
	match _slot(seat):
		1:
			return Vector2(size.x - 75.0, size.y * 0.42)
		2:
			return Vector2(size.x * 0.5, 75.0)
		3:
			return Vector2(75.0, size.y * 0.42)
	return Vector2(size.x * 0.5, size.y - 120.0)


func _table_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.42)


## Center point and rotation of card `index` in a seat's fan of `count` cards.
func _fan_pose(seat: int, index: int, count: int) -> Array:
	var radius := HAND_RADIUS if seat == HUMAN else OPPONENT_RADIUS
	var spacing := HAND_SPACING if seat == HUMAN else OPPONENT_SPACING
	if count > 1:
		spacing = minf(spacing, (HAND_MAX_SPAN if seat == HUMAN else OPPONENT_MAX_SPAN) / (count - 1))
	var facing := SEAT_FACING[_slot(seat)]
	var angle := facing + (index - (count - 1) * 0.5) * spacing / radius
	var pivot := _seat_anchor(seat) - Vector2.UP.rotated(facing) * radius
	return [pivot + Vector2.UP.rotated(angle) * radius, angle]


func _on_resized() -> void:
	_layout_static()
	_layout_hand(0.0)
	for seat in range(1, player_count):
		_layout_backs(seat, 0.0)
	_layout_table(0.0)


func _layout_static() -> void:
	button_row.position = Vector2(0, size.y - 255.0)
	button_row.size = Vector2(size.x, 44)
	status_label.position = Vector2(size.x * 0.15, size.y - 325.0)
	status_label.size = Vector2(size.x * 0.7, 60)
	last_play_label.position = Vector2(200, _table_center().y - 95.0)
	last_play_label.size = Vector2(size.x - 400.0, 30)
	language_button.position = Vector2(size.x - 130.0, 16)

	seat_labels[0].position = Vector2(20.0, size.y - 130.0)
	for seat in range(1, player_count):
		var below := 45.0 if _slot(seat) == 2 else 165.0
		seat_labels[seat].position = _seat_anchor(seat) + Vector2(-75.0, below)
	_layout_result_panel()


func _layout_result_panel() -> void:
	result_panel.reset_size()
	result_panel.position = (size - result_panel.size) * 0.5


func _layout_hand(duration: float, stagger: float = 0.0) -> void:
	var cards: Array[Card] = []
	cards.assign(hand_views.keys())
	cards.sort_custom(func(a: Card, b: Card) -> bool: return _card_order(a) < _card_order(b))
	for i in cards.size():
		var pose := _fan_pose(HUMAN, i, cards.size())
		var center: Vector2 = pose[0]
		var rotation_angle: float = pose[1]
		if selected.has(cards[i]):
			# A picked-up card slides outward along the fan, away from the pivot.
			center += Vector2.UP.rotated(rotation_angle) * SELECT_LIFT
		var view: Control = hand_views[cards[i]]
		hand_layer.move_child(view, i)
		_move(view, center, rotation_angle, Vector2.ONE, duration, i * stagger)


func _layout_backs(seat: int, duration: float, stagger: float = 0.0) -> void:
	var backs: Array = back_views[seat]
	for i in backs.size():
		var pose := _fan_pose(seat, i, backs.size())
		_move(backs[i], pose[0], pose[1], Vector2.ONE, duration, i * stagger)


func _layout_table(duration: float) -> void:
	for i in table_views.size():
		var offset := (i - (table_views.size() - 1) * 0.5) * TABLE_STEP
		_move(table_views[i], _table_center() + Vector2(offset, 0.0), 0.0, Vector2.ONE * TABLE_SCALE, duration)


## Tweens a card so its center lands on `center` (duration 0 snaps instantly).
func _move(node: Control, center: Vector2, target_rotation: float, target_scale: Vector2, duration: float, delay: float = 0.0) -> void:
	if node.has_meta("tween"):
		var old: Tween = node.get_meta("tween")
		if old.is_valid():
			old.kill()
	var target_position := center - node.size * 0.5
	if duration <= 0.0:
		node.position = target_position
		node.rotation = target_rotation
		node.scale = target_scale
		return
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", target_position, duration).set_delay(delay)
	tween.tween_property(node, "rotation", target_rotation, duration).set_delay(delay)
	tween.tween_property(node, "scale", target_scale, duration).set_delay(delay)
	node.set_meta("tween", tween)


# --- Game flow --------------------------------------------------------------

## New game: clears the running totals and deals round 1.
func _start_game() -> void:
	series.reset()
	_start_round()


## Deals the next round, keeping the running totals.
func _start_round() -> void:
	run_id += 1
	round_recorded = false
	result_panel.visible = false
	status_label.visible = true
	selected.clear()
	_set_action("")
	_deal_round()

	_clear_all_cards()
	_layout_static()
	_deal_animation()
	_refresh()
	_run_ai_turns()


func _clear_all_cards() -> void:
	for layer in [hand_layer, table_layer]:
		for child in layer.get_children():
			child.queue_free()
	hand_views.clear()
	table_views.clear()
	back_views.clear()
	back_views.append([])
	for seat in range(1, player_count):
		var backs: Array = []
		back_views.append(backs)


## Creates every hand at the middle of the table, then fans it out to each seat.
func _deal_animation() -> void:
	for seat in player_count:
		_add_to_hand(seat, game.hand_of(seat), _table_center(), DEAL_STAGGER)


## Adds new cards to a seat's fan, flying in from `from_center` (also used for the deal).
func _add_to_hand(seat: int, cards: Array, from_center: Vector2, stagger: float = 0.0) -> void:
	for card in cards:
		var view: Control
		if seat == HUMAN:
			view = CardView.new()
			view.setup(card, CARD_SIZE)
			view.pressed.connect(_on_card_pressed.bind(card))
			hand_views[card] = view
		else:
			view = CardBackView.new()
			view.setup(BACK_SIZE)
			back_views[seat].append(view)
		hand_layer.add_child(view)
		_move(view, from_center, 0.0, Vector2.ONE * 0.3, 0.0)
	if seat == HUMAN:
		_layout_hand(0.5, stagger)
	else:
		_layout_backs(seat, 0.5, stagger)


func _on_card_pressed(card: Card) -> void:
	if selected.has(card):
		selected.erase(card)
	else:
		selected.append(card)
	_layout_hand(MOVE_TIME * 0.6)
	_refresh_controls()


func _on_play_pressed() -> void:
	if not game.play(HUMAN, selected):
		_set_action("act_illegal")
		_refresh_controls()
		return

	# game.last_combo.cards is in display order, so the cards land on the table in order.
	var views: Array = []
	for card in game.last_combo.cards:
		var view: CardView = hand_views[card]
		hand_views.erase(card)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		views.append(view)
	selected.clear()
	_place_on_table(views)
	_layout_hand(MOVE_TIME)

	_set_action("act_played", [_seat_name(HUMAN)])
	_refresh()
	_run_ai_turns()


func _on_pass_pressed() -> void:
	if game.pass_turn(HUMAN):
		# Picked-up cards drop back into the fan.
		selected.clear()
		_layout_hand(MOVE_TIME)
		_set_action("act_passed", [_seat_name(HUMAN)])
		_refresh()
		_run_ai_turns()


func _on_language_pressed() -> void:
	I18n.toggle()
	_refresh()


func _run_ai_turns() -> void:
	var my_run := run_id
	while not game.is_over() and game.current_player != HUMAN:
		_refresh_controls()
		await get_tree().create_timer(AI_DELAY).timeout
		if my_run != run_id or game.is_over():
			return
		_ai_step(game.current_player)
		if my_run != run_id:
			return  # the move started a new round (e.g. a redeal)
		_refresh()


## Turns the computer player's face-down cards into the played cards and flies them to the table.
func _ai_play_animation(seat: int, played: Array[Card]) -> void:
	var backs: Array = back_views[seat]
	var views: Array = []
	var start := (backs.size() - played.size()) >> 1  # the cards come out of the middle of the fan
	for card in played:
		var back: Control = backs[start]
		backs.remove_at(start)

		var view := CardView.new()
		view.setup(card, CARD_SIZE)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		table_layer.add_child(view)
		var back_center := back.position + back.size * 0.5
		_move(view, back_center, back.rotation, Vector2.ONE * (BACK_SIZE.x / CARD_SIZE.x), 0.0)
		back.queue_free()
		views.append(view)
	_place_on_table(views)
	_layout_backs(seat, MOVE_TIME)


func _place_on_table(views: Array) -> void:
	_clear_table()
	for view in views:
		if view.get_parent() != table_layer:
			view.reparent(table_layer)
		table_views.append(view)
	_layout_table(FLY_TIME)


func _clear_table() -> void:
	for view in table_views:
		var tween := create_tween()
		tween.tween_property(view, "modulate:a", 0.0, 0.3)
		tween.tween_callback(view.queue_free)
	table_views.clear()


# --- Text and controls ------------------------------------------------------

func _set_action(key: String, args: Array = []) -> void:
	last_action_key = key
	last_action_args = args


func _refresh() -> void:
	_record_round_if_over()
	_refresh_table()
	_refresh_scoreboard()
	_refresh_controls()


func _refresh_table() -> void:
	for i in player_count:
		seat_labels[i].text = _seat_text(i)
		var active: bool = i == game.current_player and not game.is_over()
		seat_labels[i].add_theme_color_override("font_color", ACTIVE_COLOR if active else Color.WHITE)

	if not _in_play_phase():
		last_play_label.text = ""
	elif game.last_combo == null:
		last_play_label.text = I18n.t("new_round")
		_clear_table()
	else:
		last_play_label.text = "%s: %s" % [_seat_name(game.last_player), _combo_name(game.last_combo)]


func _refresh_controls() -> void:
	play_button.text = I18n.t("play")
	pass_button.text = I18n.t("pass")
	menu_button.text = I18n.t("menu")
	continue_button.text = I18n.t("continue")
	result_menu_button.text = I18n.t("back_to_menu")
	language_button.text = I18n.t("language_button")

	var playing := _in_play_phase()
	var my_turn: bool = not game.is_over() and game.current_player == HUMAN
	play_button.disabled = not my_turn or selected.is_empty()
	pass_button.disabled = not my_turn or game.last_combo == null
	play_button.visible = playing
	pass_button.visible = playing

	var action := ""
	if not last_action_key.is_empty():
		action = I18n.t(last_action_key) % last_action_args if not last_action_args.is_empty() else I18n.t(last_action_key)
	var second_line: String = _result_text() if game.is_over() else _turn_hint(my_turn)
	status_label.text = "%s\n%s" % [action, second_line]
	_refresh_extra()


func _record_round_if_over() -> void:
	if game.is_over() and not round_recorded:
		series.record(game.scores())
		round_recorded = true
		_show_result_after_delay()


## Opens the result window, then counts down and returns to the start screen
## unless the player presses Continue (which starts a new run and stops this one).
func _show_result_after_delay() -> void:
	var my_run := run_id
	await get_tree().create_timer(RESULT_DELAY).timeout
	if my_run != run_id:
		return
	result_title.text = I18n.t("round_over") % (series.round_number() - 1)
	result_body.text = _result_details()
	result_panel.visible = true
	status_label.visible = false  # the window shows the same result; avoid text peeking out around it
	for left in range(COUNTDOWN_SECONDS, 0, -1):
		countdown_label.text = I18n.t("countdown") % left
		_layout_result_panel()
		await get_tree().create_timer(1.0).timeout
		if my_run != run_id:
			return
	_go_to_menu()


func _go_to_menu() -> void:
	run_id += 1  # stops the AI loop and any countdown
	get_tree().change_scene_to_file(MENU_SCENE)


func _refresh_scoreboard() -> void:
	# While a round is being played its number is round_number(); once recorded, it is the last one.
	var shown_round := series.round_number() - (1 if round_recorded else 0)
	# Kept to three short lines so it stays clear of the left player's fan.
	var lines: Array[String] = ["%s · %s" % [I18n.t("round") % shown_round, I18n.t("totals")]]
	var leader := series.leader()
	var entries: Array[String] = []
	for i in player_count:
		entries.append("%s %+d%s" % [_seat_name(i), series.totals[i], " ★" if i == leader else ""])
	for i in range(0, entries.size(), 2):
		lines.append("   ".join(entries.slice(i, i + 2)))
	scoreboard_label.text = "\n".join(lines)


func _result_text() -> String:
	var scores: Array[int] = game.scores()
	var parts: Array[String] = []
	for i in player_count:
		parts.append("%s %+d" % [_seat_name(i), scores[i]])
	return "%s  %s" % [_result_headline(), I18n.t("score") % "  ".join(parts)]


## Result window body: the winner, then each player's score this round and running total.
func _result_details() -> String:
	var scores: Array[int] = game.scores()
	var lines: Array[String] = [_result_headline(), ""]
	for i in player_count:
		lines.append(I18n.t("result_line") % [_seat_name(i), scores[i], series.totals[i]])
	return "\n".join(lines)
