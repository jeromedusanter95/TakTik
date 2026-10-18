class_name SunRays
extends Control
## Soft gold rays turning slowly behind a victory.

const RAY_COUNT: int = 14
const TURN_SECONDS: float = 40.0

var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset_ratio = Vector2(0.5, 0.5)


func _draw() -> void:
	var centre: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0
	var half_width: float = PI / RAY_COUNT / 2.0
	for index: int in RAY_COUNT:
		var angle: float = TAU * index / RAY_COUNT
		var ray: PackedVector2Array = [
			centre,
			centre + Vector2.from_angle(angle - half_width) * radius,
			centre + Vector2.from_angle(angle + half_width) * radius,
		]
		var colours: PackedColorArray = [
			Color(UiTokens.GOLD_400, 0.22), Color(UiTokens.GOLD_400, 0.0), Color(UiTokens.GOLD_400, 0.0),
		]
		draw_polygon(ray, colours)


func start_turning() -> void:
	stop_turning()
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "rotation", TAU, TURN_SECONDS).from(0.0)


func stop_turning() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
