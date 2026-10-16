class_name PressScaleFeedback
extends Node
## Gives its parent button press feedback by tweening its scale down while
## held and back when released.

const PRESSED_SCALE: Vector2 = Vector2(0.92, 0.92)
const DURATION: float = 0.08

var _button: BaseButton = null
var _tween: Tween = null


func _ready() -> void:
	var parent: Node = get_parent()
	if parent is not BaseButton:
		push_error("PressScaleFeedback must be the child of a button")
		return
	_button = parent
	_button.pivot_offset_ratio = Vector2(0.5, 0.5)
	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)


func _on_button_down() -> void:
	_scale_to(PRESSED_SCALE)


func _on_button_up() -> void:
	_scale_to(Vector2.ONE)


func _scale_to(target: Vector2) -> void:
	if _tween != null:
		_tween.kill()
	_tween = _button.create_tween()
	_tween.tween_property(_button, "scale", target, DURATION)
