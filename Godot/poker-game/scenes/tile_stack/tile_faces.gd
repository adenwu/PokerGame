class_name TileFaces
extends RefCounted
## The pictures on the tiles, by kind number:
##   0-3  the four card suits ♠ ♥ ♦ ♣
##   then every image in res://assets/tiles/ (PNG/JPG/WebP/SVG, sorted by file name)
##   then built-in shapes, so there are always enough kinds.
## Early levels use only the first few kinds, so suits and images come first.

const IMAGE_DIR := "res://assets/tiles/"
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "svg"]

const SUITS := [["♠", Color(0.1, 0.1, 0.12)], ["♥", Color(0.82, 0.1, 0.12)], ["♦", Color(0.85, 0.28, 0.05)], ["♣", Color(0.05, 0.4, 0.2)]]
const SHAPES := [
	["star", Color(0.9, 0.65, 0.05)],
	["circle", Color(0.15, 0.4, 0.85)],
	["triangle", Color(0.2, 0.6, 0.25)],
	["square", Color(0.55, 0.25, 0.7)],
	["hexagon", Color(0.95, 0.45, 0.1)],
	["plus", Color(0.05, 0.6, 0.6)],
	["ring", Color(0.9, 0.3, 0.55)],
	["bars", Color(0.5, 0.32, 0.15)],
]

static var _images: Array = []
static var _loaded := false


static func images() -> Array:
	if not _loaded:
		_loaded = true
		var dir := DirAccess.open(IMAGE_DIR)
		if dir != null:
			var names: Array = []
			for file in dir.get_files():
				# Exported games list "x.png.import" / ".remap" instead of the image itself.
				var name := file.trim_suffix(".import").trim_suffix(".remap")
				if IMAGE_EXTENSIONS.has(name.get_extension().to_lower()) and not names.has(name):
					names.append(name)
			names.sort()
			for name in names:
				var texture = load(IMAGE_DIR + name)
				if texture is Texture2D:
					_images.append(texture)
	return _images


static func kind_count() -> int:
	return SUITS.size() + images().size() + SHAPES.size()


static func draw(canvas: CanvasItem, kind: int, rect: Rect2) -> void:
	if kind < SUITS.size():
		_draw_glyph(canvas, SUITS[kind][0], SUITS[kind][1], rect)
		return
	kind -= SUITS.size()
	if kind < images().size():
		var texture: Texture2D = images()[kind]
		var fit := minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())
		var draw_size := Vector2(texture.get_width(), texture.get_height()) * fit
		canvas.draw_texture_rect(texture, Rect2(rect.get_center() - draw_size * 0.5, draw_size), false)
		return
	kind -= images().size()
	var shape: Array = SHAPES[kind % SHAPES.size()]
	_draw_shape(canvas, shape[0], shape[1], rect)


static func _draw_glyph(canvas: CanvasItem, glyph: String, color: Color, rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var font_size := int(rect.size.y * 0.78)
	var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	canvas.draw_string(font, Vector2(rect.get_center().x - text_size.x * 0.5, baseline), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


static func _draw_shape(canvas: CanvasItem, shape: String, color: Color, rect: Rect2) -> void:
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.42
	match shape:
		"star":
			canvas.draw_colored_polygon(_star(c, r, r * 0.45, 5), color)
		"circle":
			canvas.draw_circle(c, r * 0.9, color)
		"triangle":
			canvas.draw_colored_polygon(_regular(c, r, 3, -PI / 2.0), color)
		"square":
			canvas.draw_rect(Rect2(c - Vector2.ONE * r * 0.75, Vector2.ONE * r * 1.5), color)
		"hexagon":
			canvas.draw_colored_polygon(_regular(c, r, 6, 0.0), color)
		"plus":
			canvas.draw_rect(Rect2(c - Vector2(r * 0.28, r * 0.9), Vector2(r * 0.56, r * 1.8)), color)
			canvas.draw_rect(Rect2(c - Vector2(r * 0.9, r * 0.28), Vector2(r * 1.8, r * 0.56)), color)
		"ring":
			canvas.draw_arc(c, r * 0.7, 0.0, TAU, 40, color, r * 0.35, true)
		"bars":
			for i in 3:
				var y := c.y + (i - 1) * r * 0.62
				canvas.draw_rect(Rect2(Vector2(c.x - r * 0.8, y - r * 0.18), Vector2(r * 1.6, r * 0.36)), color)


static func _regular(c: Vector2, r: float, sides: int, start: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		points.append(c + Vector2.from_angle(start + TAU * i / sides) * r)
	return points


static func _star(c: Vector2, outer: float, inner: float, points_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in points_count * 2:
		var radius := outer if i % 2 == 0 else inner
		points.append(c + Vector2.from_angle(-PI / 2.0 + PI * i / points_count) * radius)
	return points
