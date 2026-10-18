class_name Sparkle
extends Control
## A small four point star that twinkles.

var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset_ratio = Vector2(0.5, 0.5)


func _draw() -> void:
	var centre: Vector2 = size / 2.0
	var outer: float = minf(size.x, size.y) / 2.0
	var star: PackedVector2Array = []
	for index: int in 8:
		var radius: float = outer if index % 2 == 0 else outer * 0.28
		star.append(centre + Vector2.from_angle(TAU * index / 8.0 - PI / 2.0) * radius)
	draw_colored_polygon(star, UiTokens.GOLD_FOCUS)


## Twinkles every [param period] seconds, starting after [param delay].
func twinkle(period: float, delay: float) -> void:
	stop()
	_tween = create_tween().set_loops()
	_tween.tween_interval(delay)
	_tween.tween_property(self, "scale", Vector2.ONE, period * 0.3).from(Vector2.ONE * 0.3)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, period * 0.3).from(0.0)
	_tween.tween_property(self, "modulate:a", 0.0, period * 0.7)


func stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
