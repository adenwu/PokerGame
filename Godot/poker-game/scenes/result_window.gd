class_name ResultWindow
extends PanelContainer
## The window that opens when a round or level ends: a title, a body, a
## countdown line and two buttons (continue / back to the start screen).
## Owners fill the texts, connect the buttons and run the countdown.

const ACCENT := Color(1.0, 0.9, 0.3)

var title_label: Label
var body_label: Label
var countdown_label: Label
var continue_button: Button
var menu_button: Button


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.12, 0.08)
	style.border_color = ACCENT
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	add_theme_stylebox_override("panel", style)
	visible = false

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	title_label = _label(34)
	title_label.add_theme_color_override("font_color", ACCENT)
	column.add_child(title_label)
	body_label = _label(22)
	column.add_child(body_label)
	countdown_label = _label(18)
	countdown_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	column.add_child(countdown_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	continue_button = _button(150)
	row.add_child(continue_button)
	menu_button = _button(170)
	row.add_child(menu_button)


## Re-centres the window in `area` after its texts changed.
func center_in(area: Vector2) -> void:
	reset_size()
	position = (area - size) * 0.5


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(width: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(width, 48)
	button.add_theme_font_size_override("font_size", 22)
	return button
