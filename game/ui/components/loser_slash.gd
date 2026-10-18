class_name LoserSlash
extends Control
## A red slash across a Piece that lost a Fight.

const WIDTH: float = 5.0
const ANGLE_DEGREES: float = -35.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var half: Vector2 = Vector2.from_angle(deg_to_rad(ANGLE_DEGREES)) * minf(size.x, size.y) * 0.5
	var centre: Vector2 = size / 2.0
	draw_line(centre - half, centre + half, UiTokens.RED_400, WIDTH, true)
