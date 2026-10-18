class_name StarBurst
extends Control
## A gold star that flashes where two Pieces meet in a Fight, then frees
## itself.

const POINTS: int = 8
const INNER_RATIO: float = 0.38


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset_ratio = Vector2(0.5, 0.5)


func _draw() -> void:
	var centre: Vector2 = size / 2.0
	var outer: float = minf(size.x, size.y) / 2.0
	var star: PackedVector2Array = []
	for index: int in POINTS * 2:
		var radius: float = outer if index % 2 == 0 else outer * INNER_RATIO
		var angle: float = TAU * index / (POINTS * 2.0) - PI / 2.0
		star.append(centre + Vector2.from_angle(angle) * radius)
	draw_colored_polygon(star, UiTokens.GOLD_FOCUS)


## Grows and fades over [param duration] seconds, then frees itself.
func play(duration: float) -> void:
	scale = Vector2.ONE * 0.2
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.2, duration).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)
