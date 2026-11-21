extends Control
## Start screen in three steps:
##   1. Home: the title and a Start button.
##   2. Game list: pick a game (e.g. Big Two).
##   3. That game's options (number of players), then start playing.

enum Page { HOME, GAMES, OPTIONS }

const SELECTED_COLOR := Color(1.0, 0.9, 0.3)

# Games on the game list: title key, the table scene it opens, and either a
# choice of player counts (saved in GameSettings) or a fixed count.
const GAMES := [
	{"title": "game_big_two", "scene": "res://scenes/big_two/big_two_table.tscn", "players": [3, 4]},
	{"title": "game_dou_di_zhu", "scene": "res://scenes/dou_di_zhu/dou_di_zhu_table.tscn", "players": [3]},
]

var page := Page.HOME
var chosen_game := 0  # index into GAMES

var title_label: Label
var home_page: Control
var home_start_button: Button
var sfx_button: Button
var music_button: Button
var game_page: VBoxContainer
var game_buttons: Array[Button] = []
var options_page: VBoxContainer
var players_label: Label
var count_buttons: Dictionary = {}  # player count -> Button
var start_button: Button
var back_button: Button
var language_button: Button


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	add_child(FeltBackground.new())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	center.add_child(column)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	title_label.add_theme_constant_override("outline_size", 8)
	column.add_child(title_label)

	# Step 1: home.
	home_start_button = _big_button()
	home_start_button.pressed.connect(_show_page.bind(Page.GAMES))
	var home := VBoxContainer.new()
	home.add_theme_constant_override("separation", 24)
	home.add_child(_centered(home_start_button))
	# Sound and music switches (music is only remembered for now: none is added yet).
	var audio_row := HBoxContainer.new()
	audio_row.alignment = BoxContainer.ALIGNMENT_CENTER
	audio_row.add_theme_constant_override("separation", 16)
	sfx_button = _switch_button(_on_sfx_pressed)
	music_button = _switch_button(_on_music_pressed)
	audio_row.add_child(sfx_button)
	audio_row.add_child(music_button)
	home.add_child(audio_row)
	home_page = home
	column.add_child(home_page)

	# Step 2: the list of games.
	game_page = VBoxContainer.new()
	game_page.add_theme_constant_override("separation", 16)
	column.add_child(game_page)
	for i in GAMES.size():
		var button := _big_button()
		button.pressed.connect(_on_game_pressed.bind(i))
		game_page.add_child(_centered(button))
		game_buttons.append(button)

	# Step 3: options for the chosen game.
	options_page = VBoxContainer.new()
	options_page.add_theme_constant_override("separation", 28)
	column.add_child(options_page)

	var count_row := HBoxContainer.new()
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	count_row.add_theme_constant_override("separation", 16)
	options_page.add_child(count_row)
	players_label = Label.new()
	players_label.add_theme_font_size_override("font_size", 24)
	count_row.add_child(players_label)
	for count in [3, 4]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(110, 48)
		button.add_theme_font_size_override("font_size", 22)
		button.toggle_mode = true
		button.pressed.connect(_on_count_pressed.bind(count))
		count_row.add_child(button)
		count_buttons[count] = button

	start_button = _big_button()
	start_button.pressed.connect(_on_start_pressed)
	options_page.add_child(_centered(start_button))

	# Back goes one step up; it sits below whichever page is showing.
	back_button = Button.new()
	back_button.custom_minimum_size = Vector2(160, 44)
	back_button.add_theme_font_size_override("font_size", 20)
	back_button.pressed.connect(_on_back_pressed)
	column.add_child(_centered(back_button))

	language_button = Button.new()
	language_button.custom_minimum_size = Vector2(110, 40)
	language_button.add_theme_font_size_override("font_size", 18)
	language_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	language_button.position = Vector2(-130, 16)
	language_button.pressed.connect(_on_language_pressed)
	add_child(language_button)


func _switch_button(handler: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 44)
	button.add_theme_font_size_override("font_size", 20)
	button.toggle_mode = true
	button.pressed.connect(handler)
	return button


func _big_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(260, 64)
	button.add_theme_font_size_override("font_size", 28)
	return button


func _centered(control: Control) -> CenterContainer:
	var box := CenterContainer.new()
	box.add_child(control)
	return box


func _show_page(new_page: Page) -> void:
	page = new_page
	_refresh()


func _refresh() -> void:
	home_page.visible = page == Page.HOME
	game_page.visible = page == Page.GAMES
	options_page.visible = page == Page.OPTIONS
	back_button.get_parent().visible = page != Page.HOME
	language_button.text = I18n.t("language_button")
	back_button.text = I18n.t("back")

	match page:
		Page.HOME:
			title_label.text = I18n.t("app_title")
			home_start_button.text = I18n.t("start")
			_show_switch(sfx_button, "sfx", GameSettings.sfx_enabled())
			_show_switch(music_button, "music", GameSettings.music_enabled())
		Page.GAMES:
			title_label.text = I18n.t("choose_game")
			for i in GAMES.size():
				game_buttons[i].text = I18n.t(GAMES[i]["title"])
		Page.OPTIONS:
			title_label.text = I18n.t(GAMES[chosen_game]["title"])
			players_label.text = I18n.t("players")
			start_button.text = I18n.t("start")
			var choices: Array = GAMES[chosen_game]["players"]
			var chosen: int = GameSettings.player_count() if choices.size() > 1 else choices[0]
			for count in count_buttons:
				var button: Button = count_buttons[count]
				button.visible = choices.has(count)
				button.disabled = choices.size() == 1  # nothing to choose: shown for information
				button.text = I18n.t("players_n") % count
				button.button_pressed = count == chosen
				button.add_theme_color_override("font_color", SELECTED_COLOR if count == chosen else Color.WHITE)
				button.add_theme_color_override("font_pressed_color", SELECTED_COLOR)
				button.add_theme_color_override("font_disabled_color", SELECTED_COLOR)


func _show_switch(button: Button, key: String, on: bool) -> void:
	button.text = I18n.t("switch") % [I18n.t(key), I18n.t("on" if on else "off")]
	button.button_pressed = on
	for prop in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(prop, SELECTED_COLOR if on else Color(1, 1, 1, 0.6))


func _on_sfx_pressed() -> void:
	GameSettings.set_sfx_enabled(not GameSettings.sfx_enabled())
	_refresh()  # the automatic button click then plays only if sound is now on


func _on_music_pressed() -> void:
	GameSettings.set_music_enabled(not GameSettings.music_enabled())
	_refresh()


func _on_game_pressed(index: int) -> void:
	chosen_game = index
	_show_page(Page.OPTIONS)


func _on_back_pressed() -> void:
	_show_page(Page.GAMES if page == Page.OPTIONS else Page.HOME)


func _on_count_pressed(count: int) -> void:
	GameSettings.set_player_count(count)
	_refresh()


func _on_language_pressed() -> void:
	I18n.toggle()
	_refresh()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAMES[chosen_game]["scene"])
