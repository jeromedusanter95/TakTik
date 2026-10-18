class_name TurnBanner
extends Control
## A gold ribbon that drops in from the top when the player's turn starts,
## stays a second, and rises away.

const HIDDEN_OFFSET: float = -180.0
const IN_TIME: float = 0.35
const HOLD_TIME: float = 1.0
const OUT_TIME: float = 0.3

## How far below the top of the screen the ribbon rests.
@export var rest_y: float = 92.0

var reduced_motion: bool = false

var _tween: Tween = null

@onready var _ribbon: PanelContainer = %Ribbon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.visible = false


func play() -> void:
	if _tween != null:
		_tween.kill()
	_ribbon.visible = true
	_ribbon.modulate.a = 1.0
	_tween = create_tween()
	if reduced_motion:
		_ribbon.position.y = rest_y
		_ribbon.modulate.a = 0.0
		_tween.tween_property(_ribbon, "modulate:a", 1.0, 0.15)
		_tween.tween_interval(HOLD_TIME)
		_tween.tween_property(_ribbon, "modulate:a", 0.0, 0.15)
	else:
		_ribbon.position.y = HIDDEN_OFFSET
		_tween.tween_property(_ribbon, "position:y", rest_y, IN_TIME).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(HOLD_TIME)
		_tween.tween_property(_ribbon, "position:y", HIDDEN_OFFSET, OUT_TIME).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_ribbon.hide)


func is_showing() -> bool:
	return _ribbon.visible
