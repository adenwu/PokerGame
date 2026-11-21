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
		"app_title": "Board Games",
		"choose_game": "Choose a game",
		"game_big_two": "Big Two",
		"game_dou_di_zhu": "Fight the Landlord",
		"landlord": "Landlord",
		"farmer": "Farmer",
		"role_tag": " (%s)",
		"no_bid": "No bid",
		"bid_n": "%d pt",
		"act_bid": "%s bids %d.",
		"act_no_bid": "%s doesn't bid.",
		"act_redeal": "Nobody bid - cards redealt.",
		"act_landlord": "%s is the landlord!",
		"hint_bid": "Your turn: bid for landlord.",
		"bidding_info": "Bidding - highest bid: %d",
		"stake_info": "Base %d  ×%d",
		"win_landlord": "The landlord (%s) wins.",
		"win_farmers": "The farmers win.",
		"spring": "Spring!",
		"anti_spring": "Anti-spring!",
		"ddz_type_0": "single",
		"ddz_type_1": "pair",
		"ddz_type_2": "triple",
		"ddz_type_3": "triple + single",
		"ddz_type_4": "triple + pair",
		"ddz_type_5": "straight",
		"ddz_type_6": "pair straight",
		"ddz_type_7": "airplane",
		"ddz_type_8": "airplane + singles",
		"ddz_type_9": "airplane + pairs",
		"ddz_type_10": "four + two",
		"ddz_type_11": "four + two pairs",
		"ddz_type_12": "bomb",
		"ddz_type_13": "rocket",
		"back": "Back",
		"players": "Players",
		"players_n": "%d players",
		"start": "Start",
		"menu": "Menu",
		"continue": "Continue",
		"back_to_menu": "Back to Menu",
		"round_over": "Round %d over",
		"countdown": "Returning to the start screen in %d s...",
		"result_line": "%s    this round %+d    total %+d",
		"round": "Round %d",
		"totals": "Totals",
		"leading": "leading",
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
		"app_title": "棋牌遊戲",
		"choose_game": "選擇遊戲",
		"game_big_two": "大老二",
		"game_dou_di_zhu": "鬥地主",
		"landlord": "地主",
		"farmer": "農民",
		"role_tag": "（%s）",
		"no_bid": "不叫",
		"bid_n": "%d 分",
		"act_bid": "%s 叫 %d 分",
		"act_no_bid": "%s 不叫",
		"act_redeal": "沒有人叫地主，重新發牌",
		"act_landlord": "%s 當地主！",
		"hint_bid": "輪到你叫地主",
		"bidding_info": "叫地主中：目前最高 %d 分",
		"stake_info": "底分 %d  倍數 ×%d",
		"win_landlord": "地主（%s）獲勝",
		"win_farmers": "農民獲勝",
		"spring": "春天！",
		"anti_spring": "反春！",
		"ddz_type_0": "單張",
		"ddz_type_1": "對子",
		"ddz_type_2": "三張",
		"ddz_type_3": "三帶一",
		"ddz_type_4": "三帶二",
		"ddz_type_5": "順子",
		"ddz_type_6": "連對",
		"ddz_type_7": "飛機",
		"ddz_type_8": "飛機帶單",
		"ddz_type_9": "飛機帶對",
		"ddz_type_10": "四帶二",
		"ddz_type_11": "四帶兩對",
		"ddz_type_12": "炸彈",
		"ddz_type_13": "王炸",
		"back": "返回",
		"players": "人數",
		"players_n": "%d 人",
		"start": "開始遊戲",
		"menu": "選單",
		"continue": "繼續",
		"back_to_menu": "回到開始畫面",
		"round_over": "第 %d 局結束",
		"countdown": "%d 秒後回到開始畫面…",
		"result_line": "%s　　本局 %+d　　總分 %+d",
		"round": "第 %d 局",
		"totals": "總分",
		"leading": "領先",
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
	config.load(SETTINGS_PATH)  # keep the other saved settings (e.g. player count)
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
