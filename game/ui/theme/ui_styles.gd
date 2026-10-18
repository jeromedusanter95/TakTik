class_name UiStyles
extends RefCounted
## Builds the style boxes of the walnut and gold look from UiTokens.

## How far the keyboard focus ring sits outside a control, and its width.
const FOCUS_OFFSET: int = 2
const FOCUS_WIDTH: int = 3
## How much lighter a button gets under the mouse.
const HOVER_LIGHTEN: float = 0.07
const DISABLED_ALPHA: float = 0.4


## A filled box with a [param border] line of [param border_width] and
## [param padding] inside.
static func box(
		fill: Color,
		radius: int,
		padding: Vector4i = Vector4i.ZERO,
		border: Color = Color.TRANSPARENT,
		border_width: int = 0,
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.content_margin_left = padding.x
	style.content_margin_top = padding.y
	style.content_margin_right = padding.z
	style.content_margin_bottom = padding.w
	style.anti_aliasing = true
	return style


## The same padding on every side.
static func even(padding: int) -> Vector4i:
	return Vector4i(padding, padding, padding, padding)


## A panel lifted off the page, as elev-panel.
static func panel(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(fill, radius, even(padding), border, 1)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0.0, 10.0)
	return style


## A raised button: a [param fill] face over a thick [param edge] bottom line.
static func raised(
		fill: Color, edge: Color, edge_width: int, radius: int, padding: Vector4i
) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(fill, radius, padding)
	style.border_color = edge
	style.border_width_bottom = edge_width
	return style


## The gold button: elev-gold, a gold face over a deep gold edge.
static func gold_button(radius: int, padding: Vector4i) -> StyleBoxFlat:
	var style: StyleBoxFlat = raised(UiTokens.GOLD_500, UiTokens.GOLD_SHADOW, 6, radius, padding)
	style.border_color = UiTokens.GOLD_SHADOW
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0.0, 8.0)
	return style


## The wood button: elev-wood, with a 2 px border-3 outline.
static func wood_button(radius: int, padding: Vector4i) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(UiTokens.WOOD_BUTTON, radius, padding, UiTokens.BORDER_3, 2)
	style.border_width_bottom = 5
	style.border_color = UiTokens.BORDER_3
	style.shadow_color = UiTokens.WOOD_EDGE
	style.shadow_size = 1
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


## [param style] as it looks under the mouse.
static func hovered(style: StyleBoxFlat) -> StyleBoxFlat:
	var copy: StyleBoxFlat = style.duplicate()
	copy.bg_color = style.bg_color.lightened(HOVER_LIGHTEN)
	return copy


## [param style] as it looks when it cannot be used: faded, without its edge
## or shadow.
static func disabled(style: StyleBoxFlat) -> StyleBoxFlat:
	var copy: StyleBoxFlat = style.duplicate()
	copy.bg_color = Color(style.bg_color, style.bg_color.a * DISABLED_ALPHA)
	copy.border_color = Color(style.border_color, style.border_color.a * DISABLED_ALPHA)
	copy.content_margin_bottom += copy.border_width_bottom - copy.border_width_top
	copy.border_width_bottom = copy.border_width_top
	copy.shadow_size = 0
	return copy


## The keyboard focus ring, 3 px gold-focus, 2 px outside a control with
## corners of [param radius].
static func focus_ring(radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = UiTokens.GOLD_FOCUS
	style.set_border_width_all(FOCUS_WIDTH)
	style.set_expand_margin_all(FOCUS_OFFSET + FOCUS_WIDTH)
	style.set_corner_radius_all(radius + FOCUS_OFFSET + FOCUS_WIDTH)
	style.anti_aliasing = true
	return style


## A box that draws nothing, for controls that only lay out their content.
static func empty(padding: Vector4i = Vector4i.ZERO) -> StyleBoxEmpty:
	var style: StyleBoxEmpty = StyleBoxEmpty.new()
	style.content_margin_left = padding.x
	style.content_margin_top = padding.y
	style.content_margin_right = padding.z
	style.content_margin_bottom = padding.w
	return style
