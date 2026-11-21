class_name GameSettings
extends RefCounted
## Choices made on the start screen, shared with the table and saved between runs.

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_PLAYER_COUNT := 4

static var _player_count := 0


static func player_count() -> int:
	if _player_count == 0:
		var config := ConfigFile.new()
		var saved := DEFAULT_PLAYER_COUNT
		if config.load(SETTINGS_PATH) == OK:
			saved = config.get_value("game", "player_count", DEFAULT_PLAYER_COUNT)
		_player_count = saved if saved == 3 or saved == 4 else DEFAULT_PLAYER_COUNT
	return _player_count


static func set_player_count(count: int) -> void:
	assert(count == 3 or count == 4, "Big Two supports 3 or 4 players")
	_player_count = count
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # keep the other saved settings (e.g. language)
	config.set_value("game", "player_count", count)
	config.save(SETTINGS_PATH)
