class_name RulesTexts
extends RefCounted
## How-to-play text for each game, shown on the start screen's rules page.
## Keyed by the game's title key (see main_menu.gd GAMES), in RichTextLabel BBCode.
## Keep these in step with the rules the code actually uses.

const H := "[font_size=24][color=#ffe066]%s[/color][/font_size]"

const TEXTS := {
	"zh_TW": {
		"game_big_two": [
			["人數與發牌", "3 人或 4 人。4 人時每人 13 張；3 人時每人 17 張，多出的 1 張給拿到梅花 3 的人。"],
			["目標", "最先把手牌出完的人獲勝。"],
			["牌的大小", "點數由小到大：3、4、5 … K、A、2（2 最大）。\n點數相同時比花色：梅花 < 方塊 < 紅心 < 黑桃。"],
			["出牌", "拿到梅花 3 的人先出。輪到你時，要出「張數相同、牌型相同、而且更大」的牌，或是選 Pass。\n其他人都 Pass 之後，最後出牌的人可以重新出任何牌型。"],
			["牌型", "・單張\n・對子：兩張同點數\n・五張牌型（由小到大）：\n　順子：五張點數連續。2-3-4-5-6 最大，A-2-3-4-5 第二；J-Q-K-A-2 這種繞回去的不算\n　同花：五張同花色\n　葫蘆：三張同點數＋一對，比三張的點數\n　鐵支：四張同點數＋任一張\n　同花順：同花色的順子\n・五張牌型要同一種才能比大小；但「鐵支」可以壓順子、同花、葫蘆，「同花順」可以壓所有五張牌型。"],
			["一條龍", "發牌後手上剛好有 3 到 2 全部 13 種點數，直接獲勝。"],
			["計分", "輸家每剩一張牌扣 10 分；剩超過 10 張，或手上還有 2，扣分加倍。贏家拿走所有輸家扣的分數。"],
		],
		"game_dou_di_zhu": [
			["人數與發牌", "固定 3 人。一副 54 張（含大小王），每人 17 張，剩下 3 張是底牌。"],
			["叫地主", "隨機一人先叫，每人輪一次：不叫、1 分、2 分或 3 分，而且要比前面的人叫得高。叫 3 分直接當地主；三人都不叫就重新發牌。\n地主拿走 3 張底牌（亮給大家看），另外兩人是農民，一起對抗地主。"],
			["目標", "地主先出完牌，地主贏；任何一個農民先出完，兩個農民一起贏。"],
			["牌的大小", "只比點數、不比花色：3 < 4 < … < K < A < 2 < 小王 < 大王。"],
			["出牌", "地主先出。之後要出「牌型相同、張數相同、而且更大」的牌，或是 Pass。\n其他人都 Pass 之後，最後出牌的人可以重新出任何牌型。"],
			["牌型", "・單張、對子、三張\n・三帶一：三張＋任一張；三帶二：三張＋一對\n・順子：5 張以上點數連續（3 到 A，不能有 2 和王）\n・連對：3 對以上點數連續\n・飛機：2 組以上連續的三張；可以帶同樣組數的單張或對子當「翅膀」\n・四帶二：四張＋兩張單牌，或四張＋兩對\n・炸彈：四張同點數，可以壓任何非炸彈的牌\n・王炸：大王＋小王，最大，什麼都能壓"],
			["計分", "分數 = 叫的分數 × 倍數。每出一個炸彈或王炸，倍數 ×2；春天（農民一張都沒出）或反春（地主只出了第一手）也 ×2。\n農民每人輸贏一份分數，地主輸贏兩份。"],
		],
		"game_tile_stack": [
			["目標", "把牌桌上的牌全部消除就過關。"],
			["玩法", "點選沒有被壓住的牌，它會移到下方的卡槽。卡槽裡湊滿 3 張相同圖案就會消除。\n被其他牌壓住的牌會變暗，不能點。"],
			["失敗", "卡槽最多放 7 張。放滿了又沒有 3 張相同可以消除，就失敗。"],
			["關卡", "每一關都一定有解。越後面的關卡圖案種類越多、疊得越多層，牌也會錯開半張、四分之一張；被壓住的牌變暗得越少，越來越難看出哪張其實還被壓著。中後段兩側還會出現牌堆，一次只能拿最上面那張。"],
			["工具牌（每關各一次）", "・返回：收回上一步\n・彈回：從卡槽隨機拿三張放回牌桌\n・刷新：打亂牌桌上還沒消除的牌"],
			["一鍵完成", "當剩下的牌都沒被壓住，或只剩一種圖案時，右上角會出現「一鍵完成」，按下去就自動完成這一關。"],
		],
	},
	"en": {
		"game_big_two": [
			["Players and dealing", "3 or 4 players. With 4, everyone gets 13 cards; with 3, everyone gets 17 and the one card left over goes to whoever holds the 3 of clubs."],
			["Goal", "Be the first to play out all your cards."],
			["Card order", "Lowest to highest: 3, 4, 5 … K, A, 2 (2 is highest).\nEqual ranks are broken by suit: clubs < diamonds < hearts < spades."],
			["Playing", "Whoever holds the 3 of clubs starts. On your turn, play the same number of cards and the same kind of hand, but higher, or pass.\nWhen everyone else has passed, the last player to play may lead any hand."],
			["Hands", "• Single\n• Pair: two of the same rank\n• Five-card hands (lowest to highest):\n   Straight: five ranks in a row. 2-3-4-5-6 is highest, A-2-3-4-5 second; wrap-arounds like J-Q-K-A-2 don't count\n   Flush: five of one suit\n   Full house: three of a kind + a pair, compared by the three\n   Four of a kind: four of a rank + any card\n   Straight flush: a straight in one suit\n• Five-card hands only beat the same kind, except that four of a kind beats straights, flushes and full houses, and a straight flush beats every five-card hand."],
			["Dragon", "If your dealt hand holds all 13 ranks (3 to 2), you win at once."],
			["Scoring", "Losers pay 10 points per card left, doubled if they hold more than 10 cards or any 2. The winner collects it all."],
		],
		"game_dou_di_zhu": [
			["Players and dealing", "Always 3 players. One 54-card deck (with both jokers): 17 cards each and 3 bottom cards."],
			["Bidding", "A random player bids first and each bids once: no bid, 1, 2 or 3 points, higher than the bid before. A bid of 3 wins at once; if nobody bids, the cards are redealt.\nThe landlord takes the 3 bottom cards (shown to all); the other two are farmers playing together against the landlord."],
			["Goal", "The landlord wins by playing out first; if either farmer plays out first, both farmers win."],
			["Card order", "Ranks only, suits don't matter: 3 < 4 < … < K < A < 2 < small joker < big joker."],
			["Playing", "The landlord leads. After that, play the same kind of hand with the same number of cards, but higher, or pass.\nWhen everyone else has passed, the last player to play may lead anything."],
			["Hands", "• Single, pair, three of a kind\n• Three + one: three + any card; three + pair\n• Straight: 5 or more ranks in a row (3 to A, no 2s or jokers)\n• Pair run: 3 or more pairs in a row\n• Airplane: 2 or more threes in a row, optionally with as many singles or pairs as \"wings\"\n• Four + two: four of a kind + two singles, or + two pairs\n• Bomb: four of a kind, beats anything that isn't a bomb\n• Rocket: both jokers, beats everything"],
			["Scoring", "Score = bid × multiplier. Each bomb or rocket doubles the multiplier; so does a spring (farmers never played) or anti-spring (the landlord only played the first lead).\nEach farmer wins or loses the score once, the landlord twice."],
		],
		"game_tile_stack": [
			["Goal", "Clear every tile from the table to pass the level."],
			["Playing", "Click a tile that isn't covered and it moves into the tray below. Three alike in the tray disappear.\nTiles covered by others are darker and can't be clicked."],
			["Losing", "The tray holds 7 tiles. If it fills up with no three alike, the level is lost."],
			["Levels", "Every level can be solved. Later levels have more kinds and more layers, shifted by half or quarter tiles, and covered tiles are dimmed less, so it gets harder to see what is still covered. Side piles appear later on; only their top tile can be taken."],
			["Tool tiles (once per level each)", "• Undo: take back the last pick\n• Pop out: put three random tray tiles back on the table\n• Refresh: mix up the tiles still on the table"],
			["Finish", "When every tile left is uncovered, or only one kind is left, a Finish button appears at the top right and completes the level for you."],
		],
	},
}


## The rules of a game as BBCode, in the current language.
static func for_game(title_key: String) -> String:
	var sections: Array = TEXTS.get(I18n.current(), TEXTS["zh_TW"]).get(title_key, [])
	var parts: Array[String] = []
	for section in sections:
		parts.append((H % section[0]) + "\n" + section[1])
	return "\n\n".join(parts)
