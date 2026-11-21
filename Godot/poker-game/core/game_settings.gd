class_name GameSettings
extends RefCounted
## Choices made on the start screen (language, player count, sound, music),
## shared with every screen and saved between runs in user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_PLAYER_COUNT := 4

## Tests set this to false so they never change the player's saved settings.
static var save_to_disk := true

static var _values := {}  # "section/key" -> value, cached after first read


static func player_count() -> int:
	var saved: int = _read("game", "player_count", DEFAULT_PLAYER_COUNT)
	return saved if saved == 3 or saved == 4 else DEFAULT_PLAYER_COUNT


static func set_player_count(count: int) -> void:
	assert(count == 3 or count == 4, "Big Two supports 3 or 4 players")
	_write("game", "player_count", count)


static func sfx_enabled() -> bool:
	return _read("audio", "sfx", true)


static func set_sfx_enabled(on: bool) -> void:
	_write("audio", "sfx", on)


## Saved now so the switch already works; there is no music to play yet.
static func music_enabled() -> bool:
	return _read("audio", "music", true)


static func set_music_enabled(on: bool) -> void:
	_write("audio", "music", on)


static func locale() -> String:
	return _read("ui", "locale", "")


static func set_locale(value: String) -> void:
	_write("ui", "locale", value)


static func _read(section: String, key: String, default_value: Variant) -> Variant:
	var id := section + "/" + key
	if not _values.has(id):
		var config := ConfigFile.new()
		var loaded := config.load(SETTINGS_PATH) == OK
		_values[id] = config.get_value(section, key, default_value) if loaded else default_value
	return _values[id]


static func _write(section: String, key: String, value: Variant) -> void:
	_values[section + "/" + key] = value
	if not save_to_disk:
		return
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # keep the other saved settings
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)
