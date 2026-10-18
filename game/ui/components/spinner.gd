class_name Spinner
extends Control
## A gold arc turning while something is on its way.

const TURN_SECONDS: float = 0.9

var reduced_motion: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var centre: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - 3.0
	draw_arc(centre, radius, 0.0, TAU, 40, UiTokens.SURFACE_SUNKEN, 4.0, true)
	var start: float = 0.0 if reduced_motion else TAU * fposmod(Time.get_ticks_msec() / 1000.0, TURN_SECONDS) / TURN_SECONDS
	draw_arc(centre, radius, start, start + PI * 0.6, 20, UiTokens.GOLD_500, 4.0, true)
