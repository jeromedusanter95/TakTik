class_name PageBackground
extends Control
## The page behind every screen: the walnut gradient, a soft glow behind the
## main element and a faint wood grain.

const GLOW_STEPS: int = 28
const GRAIN_SPACING: float = 11.0
const GRAIN_ALPHA: float = 0.03

## Where the glow sits, as a fraction of the page size.
@export var glow_center: Vector2 = Vector2(0.5, 0.45)
## The glow's radius, as a fraction of the page's shorter side.
@export var glow_radius: float = 0.55


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var corners: PackedVector2Array = [
		Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y),
	]
	var colours: PackedColorArray = [
		UiTokens.BG_TOP, UiTokens.BG_TOP, UiTokens.BG_BOTTOM, UiTokens.BG_BOTTOM,
	]
	draw_polygon(corners, colours)
	_draw_glow()
	_draw_grain()


## A radial glow, faked with stacked circles that fade towards the edge.
func _draw_glow() -> void:
	var centre: Vector2 = size * glow_center
	var radius: float = minf(size.x, size.y) * glow_radius
	var step_alpha: float = UiTokens.BG_GLOW.a / GLOW_STEPS
	for step: int in GLOW_STEPS:
		var fraction: float = 1.0 - float(step) / GLOW_STEPS
		draw_circle(centre, radius * fraction, Color(UiTokens.BG_GLOW, step_alpha))


func _draw_grain() -> void:
	var line: Color = Color(1.0, 0.9, 0.75, GRAIN_ALPHA)
	var y: float = GRAIN_SPACING
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), line, 1.0)
		y += GRAIN_SPACING
