class_name CardView
extends Button
## Draws one card face as a button: rank on top, suit below.

const SUIT_SYMBOLS: Array[String] = ["♣", "♦", "♥", "♠"]
const RED := Color(0.8, 0.1, 0.1)
const BLACK := Color(0.1, 0.1, 0.1)


func setup(card: Card, card_size: Vector2) -> void:
	custom_minimum_size = card_size
	size = card_size
	pivot_offset = card_size * 0.5  # rotate and scale around the center
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_LEFT  # overlapped hand cards only show their left edge
	text = "%s\n%s" % [Card.RANK_NAMES[card.rank], SUIT_SYMBOLS[card.suit]]
	add_theme_font_size_override("font_size", int(card_size.y * 0.24))

	var is_red := card.suit == Card.Suit.DIAMONDS or card.suit == Card.Suit.HEARTS
	for prop in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(prop, RED if is_red else BLACK)

	var face := _make_style(Color.WHITE)
	var hover := _make_style(Color(1.0, 0.97, 0.8))
	for style_name in ["normal", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style_name, face)
	add_theme_stylebox_override("hover", hover)


func _make_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.35, 0.35, 0.35)
	style.content_margin_left = 10
	return style
