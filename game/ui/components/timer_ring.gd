class_name TimerRing
extends Control
## A countdown drawn as a ring that empties clockwise, with the time left in
## its centre. Under 10 seconds it turns red; in the last 3 it beats once a
## second.

const RING_WIDTH: float = 5.0
const WARNING_SECONDS: int = 10
const BEAT_SECONDS: int = 3
const BEAT_SCALE: float = 1.09
const BEAT_DURATION: float = 0.12

## The ring's colour while the time is not short.
@export var colour: Color = UiTokens.GOLD_500

var reduced_motion: bool = false

var _seconds_left: int = 0
var _total_seconds: int = 1
var _beat: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset_ratio = Vector2(0.5, 0.5)
	resized.connect(queue_redraw)


func _draw() -> void:
	var diameter: float = minf(size.x, size.y)
	var centre: Vector2 = size / 2.0
	var radius: float = diameter / 2.0 - RING_WIDTH / 2.0
	draw_arc(centre, radius, 0.0, TAU, 48, UiTokens.SURFACE_SUNKEN, RING_WIDTH, true)
	var fraction: float = clampf(float(_seconds_left) / _total_seconds, 0.0, 1.0)
	if fraction > 0.0:
		var start: float = -PI / 2.0
		draw_arc(centre, radius, start, start + TAU * fraction, 48, _ring_colour(), RING_WIDTH, true)
	var text: String = TimerRing.format(_seconds_left)
	var font: Font = UiFonts.nunito(900)
	var font_size: int = roundi(diameter * 0.27)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline: float = centre.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	draw_string(
		font, Vector2(centre.x - text_size.x / 2.0, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, UiTokens.TEXT_PRIMARY
	)


## Shows [param seconds_left] of [param total_seconds].
func show_time(seconds_left: int, total_seconds: int) -> void:
	var changed: bool = seconds_left != _seconds_left
	_seconds_left = maxi(0, seconds_left)
	_total_seconds = maxi(1, total_seconds)
	queue_redraw()
	if changed and _seconds_left > 0 and _seconds_left <= BEAT_SECONDS:
		_play_beat()


func is_warning() -> bool:
	return _seconds_left < WARNING_SECONDS


## [param seconds] as m:ss, for example 2:05.
static func format(seconds: int) -> String:
	var whole: int = maxi(0, seconds)
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]


func _ring_colour() -> Color:
	return UiTokens.RED_400 if is_warning() else colour


func _play_beat() -> void:
	if reduced_motion:
		return
	if _beat != null:
		_beat.kill()
	_beat = create_tween()
	_beat.tween_property(self, "scale", Vector2.ONE * BEAT_SCALE, BEAT_DURATION).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	_beat.tween_property(self, "scale", Vector2.ONE, BEAT_DURATION)
