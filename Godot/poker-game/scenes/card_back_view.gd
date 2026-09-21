class_name CardBackView
extends Panel
## The back of a card, used for the computer players' hands.


func setup(card_size: Vector2) -> void:
	custom_minimum_size = card_size
	size = card_size
	pivot_offset = card_size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.26, 0.62)
	style.set_corner_radius_all(6)
	style.set_border_width_all(3)
	style.border_color = Color.WHITE
	add_theme_stylebox_override("panel", style)
