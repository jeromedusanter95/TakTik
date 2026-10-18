class_name BoardShapes
extends RefCounted
## Drawing helpers the Board needs that CanvasItem lacks: diagonal stripes
## clipped to a rectangle and a dashed outline.


## Fills [param rect] with 135 degree stripes of [param width], alternating
## [param first] and [param second].
static func draw_stripes(
		canvas: CanvasItem, rect: Rect2, first: Color, second: Color, width: float
) -> void:
	canvas.draw_rect(rect, second)
	var clip: PackedVector2Array = [
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
	]
	var reach: float = rect.size.x + rect.size.y
	var offset: float = -rect.size.y
	while offset < rect.size.x:
		var start: Vector2 = rect.position + Vector2(offset, 0.0)
		var stripe: PackedVector2Array = [
			start,
			start + Vector2(width, 0.0),
			start + Vector2(width + reach, reach),
			start + Vector2(reach, reach),
		]
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(stripe, clip):
			canvas.draw_colored_polygon(piece, first)
		offset += width * 2.0


## Outlines [param rect] with dashes of [param dash] length.
static func draw_dashed_rect(
		canvas: CanvasItem, rect: Rect2, colour: Color, width: float, dash: float
) -> void:
	var corners: Array[Vector2] = [
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
	]
	for index: int in corners.size():
		canvas.draw_dashed_line(corners[index], corners[(index + 1) % corners.size()], colour, width, dash)


## A rounded ring of [param width] inside [param rect], with an optional glow.
static func ring(colour: Color, width: int, radius: int, glow: Color = Color.TRANSPARENT, glow_size: int = 0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = colour
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = glow
	style.shadow_size = glow_size
	style.anti_aliasing = true
	return style
