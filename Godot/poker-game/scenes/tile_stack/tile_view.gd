class_name TileView
extends Control
## One mahjong-style tile: an ivory face over a green "thickness" edge, with a
## picture from TileFaces. Emits `picked` when clicked.

signal picked

const FACE := Vector2(56, 72)
const DEPTH := Vector2(4, 6)  # how far the green side shows below/right of the face
const FACE_COLOR := Color(0.97, 0.95, 0.88)
const EDGE_COLOR := Color(0.12, 0.42, 0.28)
const BORDER_COLOR := Color(0.68, 0.65, 0.56)

var kind := 0
var tile  # TileStackGame.Tile this view shows

var _face_style: StyleBoxFlat
var _edge_style: StyleBoxFlat


func _init() -> void:
	size = FACE + DEPTH
	custom_minimum_size = size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_face_style = StyleBoxFlat.new()
	_face_style.bg_color = FACE_COLOR
	_face_style.border_color = BORDER_COLOR
	_face_style.set_border_width_all(1)
	_face_style.set_corner_radius_all(7)
	_edge_style = StyleBoxFlat.new()
	_edge_style.bg_color = EDGE_COLOR
	_edge_style.set_corner_radius_all(8)


func set_kind(value: int) -> void:
	kind = value
	queue_redraw()


func _draw() -> void:
	_edge_style.draw(get_canvas_item(), Rect2(DEPTH, FACE))
	_face_style.draw(get_canvas_item(), Rect2(Vector2.ZERO, FACE))
	TileFaces.draw(self, kind, Rect2(Vector2(8, 10), FACE - Vector2(16, 20)))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		picked.emit()
		accept_event()
