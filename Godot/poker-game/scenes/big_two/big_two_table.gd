extends Control
## Big Two table: you sit at the bottom, three computer players take turns
## counterclockwise (right, top, left). Every hand is drawn as a fan of cards.

const HUMAN := 0
const PLAYER_COUNT := 4
const AI_DELAY := 0.9

const CARD_SIZE := Vector2(76, 108)
const BACK_SIZE := Vector2(50, 72)
const TABLE_SCALE := 0.8
const TABLE_STEP := 62.0

# Fan geometry: cards sit on a circle of `radius`; spacing is the arc length between cards.
const HAND_RADIUS := 1300.0
const HAND_SPACING := 50.0
const OPPONENT_RADIUS := 420.0
const OPPONENT_SPACING := 20.0
const SELECT_LIFT := 34.0

const MOVE_TIME := 0.25
const FLY_TIME := 0.35
const DEAL_STAGGER := 0.03
const ACTIVE_COLOR := Color(1.0, 0.9, 0.3)

# Direction each seat's cards face (toward the table center), in radians.
const SEAT_FACING: Array[float] = [0.0, -PI / 2.0, PI, PI / 2.0]

var game := BigTwoGame.new()
var selected: Array[Card] = []
var last_action_key := ""
var last_action_args: Array = []
var run_id := 0  # bumped on every new game so a stale AI loop stops itself

var hand_views: Dictionary = {}  # Card -> CardView, your hand
var back_views: Array = []  # per seat: Array of CardBackView (index 0 unused)
var table_views: Array = []  # cards currently shown in the middle

var seat_labels: Array[Label] = []
var last_play_label: Label
var status_label: Label
var button_row: HBoxContainer
var play_button: Button
var pass_button: Button
var new_game_button: Button
var language_button: Button
var hand_layer: Control
var table_layer: Control


func _ready() -> void:
	_build_ui()
	resized.connect(_on_resized)
	_start_game()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.09, 0.35, 0.2)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	for i in PLAYER_COUNT:
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
	new_game_button = _make_button(_start_game)

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


func _make_button(handler: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(130, 44)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(handler)
	button_row.add_child(button)
	return button


# --- Layout -----------------------------------------------------------------

func _seat_anchor(seat: int) -> Vector2:
	match seat:
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
	var facing := SEAT_FACING[seat]
	var angle := facing + (index - (count - 1) * 0.5) * spacing / radius
	var pivot := _seat_anchor(seat) - Vector2.UP.rotated(facing) * radius
	return [pivot + Vector2.UP.rotated(angle) * radius, angle]


func _on_resized() -> void:
	_layout_static()
	_layout_hand(0.0)
	for seat in range(1, PLAYER_COUNT):
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
	seat_labels[1].position = _seat_anchor(1) + Vector2(-75.0, 165.0)
	seat_labels[2].position = _seat_anchor(2) + Vector2(-75.0, 45.0)
	seat_labels[3].position = _seat_anchor(3) + Vector2(-75.0, 165.0)


func _layout_hand(duration: float, stagger: float = 0.0) -> void:
	var cards: Array[Card] = []
	cards.assign(hand_views.keys())
	cards.sort_custom(func(a: Card, b: Card) -> bool: return BigTwoCombo.strength(a) < BigTwoCombo.strength(b))
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

func _start_game() -> void:
	run_id += 1
	selected.clear()
	_set_action("")
	game.start(PLAYER_COUNT)
	if game.is_over():
		_set_action("act_dragon", [I18n.t("seat_%d" % game.winner)])

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
	for seat in range(1, PLAYER_COUNT):
		var backs: Array = []
		back_views.append(backs)


## Creates every hand at the middle of the table, then fans it out to each seat.
func _deal_animation() -> void:
	var from_center := _table_center()
	for card in game.hand_of(HUMAN):
		var view := CardView.new()
		view.setup(card, CARD_SIZE)
		view.pressed.connect(_on_card_pressed.bind(card))
		hand_layer.add_child(view)
		hand_views[card] = view
		_move(view, from_center, 0.0, Vector2.ONE * 0.3, 0.0)
	_layout_hand(0.5, DEAL_STAGGER)

	for seat in range(1, PLAYER_COUNT):
		for i in game.hand_of(seat).size():
			var back := CardBackView.new()
			back.setup(BACK_SIZE)
			hand_layer.add_child(back)
			back_views[seat].append(back)
			_move(back, from_center, 0.0, Vector2.ONE * 0.3, 0.0)
		_layout_backs(seat, 0.5, DEAL_STAGGER)


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

	# game.last_combo.cards is sorted, so the cards land on the table in order.
	var views: Array = []
	for card in game.last_combo.cards:
		var view: CardView = hand_views[card]
		hand_views.erase(card)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		views.append(view)
	selected.clear()
	_place_on_table(views)
	_layout_hand(MOVE_TIME)

	_set_action("act_played", [I18n.t("seat_%d" % HUMAN)])
	_refresh()
	_run_ai_turns()


func _on_pass_pressed() -> void:
	if game.pass_turn(HUMAN):
		# Picked-up cards drop back into the fan.
		selected.clear()
		_layout_hand(MOVE_TIME)
		_set_action("act_passed", [I18n.t("seat_%d" % HUMAN)])
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
		if my_run != run_id:
			return
		var player := game.current_player
		var cards := BigTwoAI.choose_play(game, player)
		var seat_name := I18n.t("seat_%d" % player)
		if cards.is_empty():
			game.pass_turn(player)
			_set_action("act_passed", [seat_name])
		else:
			game.play(player, cards)
			_ai_play_animation(player, game.last_combo.cards)
			_set_action("act_played", [seat_name])
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
	_refresh_table()
	_refresh_controls()


func _refresh_table() -> void:
	for i in PLAYER_COUNT:
		var count_text := I18n.t("cards_left") % game.hand_of(i).size()
		seat_labels[i].text = "%s\n%s" % [I18n.t("seat_%d" % i), count_text]
		var active := i == game.current_player and not game.is_over()
		seat_labels[i].add_theme_color_override("font_color", ACTIVE_COLOR if active else Color.WHITE)

	if game.last_combo == null:
		last_play_label.text = I18n.t("new_round")
		_clear_table()
	else:
		last_play_label.text = "%s: %s" % [I18n.t("seat_%d" % game.last_player), I18n.t("type_%d" % game.last_combo.type)]


func _refresh_controls() -> void:
	play_button.text = I18n.t("play")
	pass_button.text = I18n.t("pass")
	new_game_button.text = I18n.t("new_game")
	language_button.text = I18n.t("language_button")

	var my_turn := not game.is_over() and game.current_player == HUMAN
	play_button.disabled = not my_turn or selected.is_empty()
	pass_button.disabled = not my_turn or game.last_combo == null

	var action := ""
	if not last_action_key.is_empty():
		action = I18n.t(last_action_key) % last_action_args if not last_action_args.is_empty() else I18n.t(last_action_key)
	var second_line := ""
	if game.is_over():
		second_line = _result_text()
	elif my_turn:
		second_line = I18n.t("hint_lead" if game.last_combo == null else "hint_beat")
	else:
		second_line = I18n.t("thinking") % I18n.t("seat_%d" % game.current_player)
	status_label.text = "%s\n%s" % [action, second_line]


func _result_text() -> String:
	var scores := game.scores()
	var parts: Array[String] = []
	for i in PLAYER_COUNT:
		parts.append("%s %+d" % [I18n.t("seat_%d" % i), scores[i]])
	var headline := I18n.t("win_you") if game.winner == HUMAN else I18n.t("win_other") % I18n.t("seat_%d" % game.winner)
	return "%s  %s" % [headline, I18n.t("score") % "  ".join(parts)]
