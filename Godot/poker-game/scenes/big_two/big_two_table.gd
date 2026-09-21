extends Control
## Big Two table: you sit at the bottom, three computer players take turns
## counterclockwise (right, top, left).

const HUMAN := 0
const PLAYER_COUNT := 4
const PLAYER_NAMES: Array[String] = ["You", "Right", "Top", "Left"]
const AI_DELAY := 0.9
const CARD_SIZE := Vector2(76, 108)
const SMALL_CARD_SIZE := Vector2(58, 82)
const HAND_STEP := 52.0
const SELECT_LIFT := 26.0
const ACTIVE_COLOR := Color(1.0, 0.9, 0.3)

var game := BigTwoGame.new()
var selected: Array[Card] = []
var last_action := ""
var run_id := 0  # bumped on every new game so a stale AI loop stops itself

var seat_labels: Array[Label] = []
var last_play_label: Label
var last_play_box: HBoxContainer
var status_label: Label
var button_row: HBoxContainer
var play_button: Button
var pass_button: Button
var hand_area: Control


func _ready() -> void:
	_build_ui()
	resized.connect(_layout)
	_layout()
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
		add_child(label)
		seat_labels.append(label)

	last_play_label = Label.new()
	last_play_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	last_play_label.add_theme_font_size_override("font_size", 20)
	add_child(last_play_label)

	last_play_box = HBoxContainer.new()
	last_play_box.alignment = BoxContainer.ALIGNMENT_CENTER
	last_play_box.add_theme_constant_override("separation", 8)
	add_child(last_play_box)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 22)
	add_child(status_label)

	button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 16)
	add_child(button_row)
	play_button = _make_button("Play", _on_play_pressed)
	pass_button = _make_button("Pass", _on_pass_pressed)
	_make_button("New Game", _start_game)

	hand_area = Control.new()
	add_child(hand_area)


func _make_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(130, 44)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(handler)
	button_row.add_child(button)
	return button


func _layout() -> void:
	var hand_top := size.y - CARD_SIZE.y - SELECT_LIFT - 20.0
	hand_area.position = Vector2(0, hand_top)
	hand_area.size = Vector2(size.x, CARD_SIZE.y + SELECT_LIFT)

	button_row.position = Vector2(0, hand_top - 60.0)
	button_row.size = Vector2(size.x, 44)
	status_label.position = Vector2(size.x * 0.15, hand_top - 130.0)
	status_label.size = Vector2(size.x * 0.7, 60)

	last_play_label.position = Vector2(200, size.y * 0.5 - 130.0)
	last_play_label.size = Vector2(size.x - 400.0, 30)
	last_play_box.position = Vector2(200, size.y * 0.5 - 90.0)
	last_play_box.size = Vector2(size.x - 400.0, SMALL_CARD_SIZE.y)

	# Turn order goes counterclockwise: 1 = right, 2 = top, 3 = left.
	seat_labels[1].position = Vector2(size.x - 170.0, size.y * 0.5 - 40.0)
	seat_labels[2].position = Vector2(size.x * 0.5 - 75.0, 20.0)
	seat_labels[3].position = Vector2(20.0, size.y * 0.5 - 40.0)
	for i in range(1, PLAYER_COUNT):
		seat_labels[i].size = Vector2(150, 60)
	seat_labels[HUMAN].position = Vector2(20.0, hand_top - 60.0)
	seat_labels[HUMAN].size = Vector2(150, 40)

	if not game.hands.is_empty():
		_refresh_hand()


func _start_game() -> void:
	run_id += 1
	selected.clear()
	last_action = ""
	game.start(PLAYER_COUNT)
	if game.is_over():
		last_action = "%s has a dragon (all 13 ranks)!" % PLAYER_NAMES[game.winner]
	_refresh()
	_run_ai_turns()


func _on_card_pressed(card: Card) -> void:
	if selected.has(card):
		selected.erase(card)
	else:
		selected.append(card)
	_refresh_hand()
	_refresh_controls()


func _on_play_pressed() -> void:
	if not game.play(HUMAN, selected):
		last_action = "That is not a legal play."
		_refresh_controls()
		return
	last_action = "You played."
	selected.clear()
	_refresh()
	_run_ai_turns()


func _on_pass_pressed() -> void:
	if game.pass_turn(HUMAN):
		selected.clear()
		last_action = "You passed."
		_refresh()
		_run_ai_turns()


func _run_ai_turns() -> void:
	var my_run := run_id
	while not game.is_over() and game.current_player != HUMAN:
		_refresh_controls()
		await get_tree().create_timer(AI_DELAY).timeout
		if my_run != run_id:
			return
		var player := game.current_player
		var cards := BigTwoAI.choose_play(game, player)
		if cards.is_empty():
			game.pass_turn(player)
			last_action = "%s passed." % PLAYER_NAMES[player]
		else:
			game.play(player, cards)
			last_action = "%s played." % PLAYER_NAMES[player]
		_refresh()


func _refresh() -> void:
	_refresh_hand()
	_refresh_table()
	_refresh_controls()


func _refresh_hand() -> void:
	for child in hand_area.get_children():
		child.queue_free()
	var sorted: Array[Card] = []
	sorted.assign(game.hand_of(HUMAN))
	sorted.sort_custom(func(a: Card, b: Card) -> bool: return BigTwoCombo.strength(a) < BigTwoCombo.strength(b))

	var total_width := HAND_STEP * (sorted.size() - 1) + CARD_SIZE.x
	var x := (size.x - total_width) * 0.5
	for card in sorted:
		var view := CardView.new()
		view.setup(card, CARD_SIZE)
		view.position = Vector2(x, 0.0 if selected.has(card) else SELECT_LIFT)
		view.pressed.connect(_on_card_pressed.bind(card))
		hand_area.add_child(view)
		x += HAND_STEP


func _refresh_table() -> void:
	for i in PLAYER_COUNT:
		seat_labels[i].text = "%s\n%d cards" % [PLAYER_NAMES[i], game.hand_of(i).size()]
		var active := i == game.current_player and not game.is_over()
		seat_labels[i].add_theme_color_override("font_color", ACTIVE_COLOR if active else Color.WHITE)

	for child in last_play_box.get_children():
		child.queue_free()
	if game.last_combo == null:
		last_play_label.text = "New round"
	else:
		last_play_label.text = "%s: %s" % [PLAYER_NAMES[game.last_player], BigTwoCombo.TYPE_NAMES[game.last_combo.type]]
		for card in game.last_combo.cards:
			var view := CardView.new()
			view.setup(card, SMALL_CARD_SIZE)
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			last_play_box.add_child(view)


func _refresh_controls() -> void:
	var my_turn := not game.is_over() and game.current_player == HUMAN
	play_button.disabled = not my_turn or selected.is_empty()
	pass_button.disabled = not my_turn or game.last_combo == null

	if game.is_over():
		status_label.text = "%s\n%s" % [last_action, _result_text()]
	elif my_turn:
		var hint := "Your turn: lead any combo." if game.last_combo == null else "Your turn: beat it or pass."
		status_label.text = "%s\n%s" % [last_action, hint]
	else:
		status_label.text = "%s\n%s is thinking..." % [last_action, PLAYER_NAMES[game.current_player]]


func _result_text() -> String:
	var scores := game.scores()
	var parts: Array[String] = []
	for i in PLAYER_COUNT:
		parts.append("%s %+d" % [PLAYER_NAMES[i], scores[i]])
	var headline := "You win!" if game.winner == HUMAN else "%s wins." % PLAYER_NAMES[game.winner]
	return "%s  Score: %s" % [headline, "  ".join(parts)]
