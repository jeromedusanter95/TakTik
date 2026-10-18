class_name Avatar
extends Control
## A player's round badge: the first letter of their name on a fill, inside a
## 3 px ring.

const RING_WIDTH: float = 3.0

var _initial: String = ""
var _fill: Color = UiTokens.NEUTRAL_AVATARS[0]
var _ring: Color = Color.TRANSPARENT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var diameter: float = minf(size.x, size.y)
	var centre: Vector2 = size / 2.0
	draw_circle(centre, diameter / 2.0, _fill)
	if _ring.a > 0.0:
		draw_circle(centre, diameter / 2.0 - RING_WIDTH / 2.0, _ring, false, RING_WIDTH, true)
	if _initial.is_empty():
		return
	var font: Font = UiFonts.display()
	var font_size: int = roundi(diameter * 0.46)
	var text_size: Vector2 = font.get_string_size(_initial, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline: float = centre.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	draw_string(
		font, Vector2(centre.x - text_size.x / 2.0, baseline), _initial,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, UiTokens.TEXT_PRIMARY
	)


## Shows [param name]'s first letter, upper case, on [param fill] inside a
## [param ring], which may be transparent.
func show_player(name: String, fill: Color, ring: Color = Color.TRANSPARENT) -> void:
	_initial = Avatar.initial_of(name)
	_fill = fill
	_ring = ring
	queue_redraw()


## The first character of [param name], upper case.
static func initial_of(name: String) -> String:
	var trimmed: String = name.strip_edges()
	return trimmed.left(1).to_upper() if not trimmed.is_empty() else "?"
