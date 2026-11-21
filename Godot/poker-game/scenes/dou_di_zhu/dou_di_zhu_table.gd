extends CardTable
## Dou Di Zhu table: 3 players. A round starts with bidding for landlord; the
## three bottom cards wait face down at the top of the table, then flip over
## and join the landlord's hand.

const BOTTOM_SCALE := 0.65
const BOTTOM_STEP := 56.0

var bid_buttons: Array[Button] = []  # index = points (0 = no bid)
var bottom_views: Array[Control] = []
var info_label: Label
var redealt := false  # the last round was thrown in because nobody bid


func _setup_game() -> void:
	game = DouDiZhuGame.new()
	player_count = DouDiZhuGame.PLAYER_COUNT


func _build_ui() -> void:
	super()
	for points in DouDiZhuGame.MAX_BID + 1:
		var button := _make_button(_on_bid_pressed.bind(points))
		button_row.move_child(button, points)  # bids come before the menu button
		bid_buttons.append(button)

	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 20)
	info_label.add_theme_color_override("font_color", ACTIVE_COLOR)
	add_child(info_label)


func _layout_static() -> void:
	super()
	info_label.position = Vector2(0, _bottom_center().y + 48.0)
	info_label.size = Vector2(size.x, 30)
	_layout_bottom(0.0)


func _deal_round() -> void:
	game.start()
	if redealt:
		_set_action("act_redeal")
		redealt = false


func _card_order(card: Card) -> int:
	return DouDiZhuCombo.sort_key(card)


func _combo_name(combo) -> String:
	return I18n.t("ddz_type_%d" % combo.type)


func _ai_choose_play(player: int) -> Array[Card]:
	return DouDiZhuAI.choose_play(game, player)


func _ai_step(player: int) -> void:
	if game.is_bidding():
		var points := DouDiZhuAI.choose_bid(game, player)
		game.bid(player, points)
		_after_bid(player, points)
	else:
		super(player)


func _in_play_phase() -> bool:
	return game.phase == DouDiZhuGame.Phase.PLAYING


func _seat_text(player: int) -> String:
	var title := _seat_name(player)
	if game.landlord >= 0:
		title += I18n.t("role_tag") % I18n.t("landlord" if player == game.landlord else "farmer")
	var detail := I18n.t("cards_left") % game.hand_of(player).size()
	if game.is_bidding() and game.bids[player] >= 0:
		detail = I18n.t("no_bid") if game.bids[player] == 0 else I18n.t("bid_n") % game.bids[player]
	return "%s\n%s" % [title, detail]


func _turn_hint(my_turn: bool) -> String:
	if game.is_bidding():
		return I18n.t("hint_bid") if my_turn else I18n.t("thinking") % _seat_name(game.current_player)
	return super(my_turn)


func _refresh_extra() -> void:
	var my_bid_turn: bool = game.is_bidding() and game.current_player == HUMAN
	for points in bid_buttons.size():
		var button := bid_buttons[points]
		button.text = I18n.t("no_bid") if points == 0 else I18n.t("bid_n") % points
		button.visible = game.is_bidding()
		button.disabled = not my_bid_turn or (points > 0 and points <= game.highest_bid)
	if game.is_bidding():
		info_label.text = I18n.t("bidding_info") % game.highest_bid
	else:
		info_label.text = I18n.t("stake_info") % [game.highest_bid, game.multiplier()]


func _play_sound(combo) -> String:
	return "bomb" if DouDiZhuCombo.is_bomb_type(combo.type) else "play"


## Farmers win or lose together.
func _human_won() -> bool:
	return game.landlord_won() == (game.landlord == HUMAN)


func _result_headline() -> String:
	var headline := ""
	if game.landlord_won():
		headline = I18n.t("win_landlord") % _seat_name(game.landlord)
	else:
		headline = I18n.t("win_farmers")
	if game.is_spring():
		headline += "  " + I18n.t("spring" if game.landlord_won() else "anti_spring")
	return headline + "\n" + I18n.t("stake_info") % [game.highest_bid, game.multiplier()]


# --- Bidding and the bottom cards ------------------------------------------

func _on_bid_pressed(points: int) -> void:
	if game.bid(HUMAN, points):
		_after_bid(HUMAN, points)
		if not game.needs_redeal:
			_refresh()
			_run_ai_turns()


func _after_bid(player: int, points: int) -> void:
	Sfx.play("pass" if points == 0 else "bid")
	_set_action("act_no_bid" if points == 0 else "act_bid", [_seat_name(player)] if points == 0 else [_seat_name(player), points])
	if game.needs_redeal:
		redealt = true
		_start_round()
	elif not game.is_bidding():
		_set_action("act_landlord", [_seat_name(game.landlord)])
		Sfx.play_series("deal", 3, 0.08)
		_reveal_bottom()


func _bottom_center() -> Vector2:
	return Vector2(size.x * 0.5, 70.0)


func _clear_all_cards() -> void:
	super()
	for view in bottom_views:
		view.queue_free()
	bottom_views.clear()


func _deal_animation() -> void:
	super()
	for i in game.bottom.size():
		var back := CardBackView.new()
		back.setup(CARD_SIZE)
		table_layer.add_child(back)
		bottom_views.append(back)
		_move(back, _table_center(), 0.0, Vector2.ONE * 0.3, 0.0)
	_layout_bottom(0.5)


func _layout_bottom(duration: float) -> void:
	for i in bottom_views.size():
		var offset := (i - (bottom_views.size() - 1) * 0.5) * BOTTOM_STEP
		_move(bottom_views[i], _bottom_center() + Vector2(offset, 0.0), 0.0, Vector2.ONE * BOTTOM_SCALE, duration)


## Flips the bottom cards face up (they stay on show) and deals copies into the landlord's hand.
func _reveal_bottom() -> void:
	for i in bottom_views.size():
		var face := CardView.new()
		face.setup(game.bottom[i], CARD_SIZE)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		table_layer.add_child(face)
		_move(face, bottom_views[i].position + bottom_views[i].size * 0.5, 0.0, Vector2.ONE * BOTTOM_SCALE, 0.0)
		bottom_views[i].queue_free()
		bottom_views[i] = face
	_add_to_hand(game.landlord, game.bottom, _bottom_center())
