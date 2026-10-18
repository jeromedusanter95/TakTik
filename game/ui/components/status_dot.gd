class_name StatusDot
extends Control
## A small coloured dot next to a status, optionally with a ring that grows
## and fades every PULSE_PERIOD, as for players online.

const PULSE_PERIOD: float = 1.6
const PULSE_GROWTH: float = 9.0
const DOT_DIAMETER: float = 10.0

var reduced_motion: bool = false

var _colour: Color = UiTokens.GREEN_400
var _pulsing: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(DOT_DIAMETER, DOT_DIAMETER)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _pulsing and not reduced_motion and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var centre: Vector2 = size / 2.0
	draw_circle(centre, DOT_DIAMETER / 2.0, _colour, true, -1.0, true)
	if not _pulsing or reduced_motion:
		return
	var phase: float = fposmod(Time.get_ticks_msec() / 1000.0, PULSE_PERIOD) / PULSE_PERIOD
	draw_circle(
		centre, DOT_DIAMETER / 2.0 + phase * PULSE_GROWTH, Color(_colour, 0.6 * (1.0 - phase)), false, 2.0, true
	)


func show_dot(colour: Color, pulsing: bool) -> void:
	_colour = colour
	_pulsing = pulsing
	queue_redraw()
