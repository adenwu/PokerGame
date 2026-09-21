class_name I18n
extends RefCounted
## Minimal two-language text lookup (Traditional Chinese / English).
## Use I18n.t("key") for plain text, or I18n.t("key") % [args] for templates.

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LOCALE := "en"

const TEXTS := {
	"en": {
		"play": "Play",
		"pass": "Pass",
		"new_game": "New Game",
		"language_button": "中文",
		"seat_0": "You",
		"seat_1": "Right",
		"seat_2": "Top",
		"seat_3": "Left",
		"cards_left": "%d cards",
		"new_round": "New round",
		"act_played": "%s played.",
		"act_passed": "%s passed.",
		"act_illegal": "That is not a legal play.",
		"act_dragon": "%s has a dragon (all 13 ranks)!",
		"hint_lead": "Your turn: lead any combo.",
		"hint_beat": "Your turn: beat it or pass.",
		"thinking": "%s is thinking...",
		"win_you": "You win!",
		"win_other": "%s wins.",
		"score": "Score: %s",
		"type_0": "single",
		"type_1": "pair",
		"type_2": "straight",
		"type_3": "flush",
		"type_4": "full house",
		"type_5": "four of a kind",
		"type_6": "straight flush",
	},
	"zh_TW": {
		"play": "出牌",
		"pass": "Pass",
		"new_game": "新遊戲",
		"language_button": "English",
		"seat_0": "你",
		"seat_1": "右家",
		"seat_2": "對家",
		"seat_3": "左家",
		"cards_left": "%d 張",
		"new_round": "新的一輪",
		"act_played": "%s 出牌",
		"act_passed": "%s Pass",
		"act_illegal": "這樣出不合規則",
		"act_dragon": "%s 拿到一條龍！",
		"hint_lead": "輪到你：可以出任何牌型",
		"hint_beat": "輪到你：壓過它或 Pass",
		"thinking": "%s 思考中…",
		"win_you": "你贏了！",
		"win_other": "%s 獲勝",
		"score": "得分：%s",
		"type_0": "單張",
		"type_1": "對子",
		"type_2": "順子",
		"type_3": "同花",
		"type_4": "葫蘆",
		"type_5": "鐵支",
		"type_6": "同花順",
	},
}

static var locale := ""


static func t(key: String) -> String:
	if locale.is_empty():
		locale = _detect_locale()
	return TEXTS[locale].get(key, key)


static func toggle() -> void:
	locale = "en" if current() == "zh_TW" else "zh_TW"
	var config := ConfigFile.new()
	config.set_value("ui", "locale", locale)
	config.save(SETTINGS_PATH)


static func current() -> String:
	if locale.is_empty():
		locale = _detect_locale()
	return locale


static func _detect_locale() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved: String = config.get_value("ui", "locale", "")
		if TEXTS.has(saved):
			return saved
	return "zh_TW" if OS.get_locale_language() == "zh" else DEFAULT_LOCALE
