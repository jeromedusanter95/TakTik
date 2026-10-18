class_name PipBar
extends Control
## A strength as a row of pips, one lit per point, out of the highest strength
## in the game.

const MAX_PIPS: int = 7
const GAP: float = 4.0

enum Stat {
	ATTACK,
	DEFENSE,
}

## Attack pips are red, Defense pips blue.
@export var stat: Stat = Stat.ATTACK

var _value: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var pip_width: float = (size.x - GAP * (MAX_PIPS - 1)) / MAX_PIPS
	for index: int in MAX_PIPS:
		var pip: Rect2 = Rect2(Vector2(index * (pip_width + GAP), 0.0), Vector2(pip_width, size.y))
		var lit: Color = UiTokens.RED_400 if stat == Stat.ATTACK else UiTokens.DEF_400
		var fill: Color = lit if index < _value else UiTokens.SURFACE_SUNKEN
		draw_style_box(UiStyles.box(fill, UiTokens.SPACE_XS), pip)


func show_value(value: int) -> void:
	_value = clampi(value, 0, MAX_PIPS)
	queue_redraw()
