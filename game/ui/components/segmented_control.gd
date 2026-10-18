class_name SegmentedControl
extends PanelContainer
## Two or three options side by side on a sunken track; the chosen one is
## gold. Labels may be translation keys.

signal option_chosen(index: int)

## The smallest size of one option.
@export var option_minimum_size: Vector2 = Vector2(48, 36)
## Draws the chosen option as a wood tab instead of gold.
@export var tabs: bool = false

var _row: HBoxContainer = HBoxContainer.new()
var _group: ButtonGroup = ButtonGroup.new()
var _buttons: Array[Button] = []


func _init() -> void:
	theme_type_variation = &"SegmentTrack"
	_row.add_theme_constant_override("separation", 4)
	add_child(_row)


## Replaces the options with [param labels] and chooses [param selected].
func show_options(labels: PackedStringArray, selected: int) -> void:
	for button: Button in _buttons:
		_row.remove_child(button)
		button.queue_free()
	_buttons.clear()
	for index: int in labels.size():
		var button: Button = Button.new()
		button.theme_type_variation = &"TabButton" if tabs else &"SegmentButton"
		button.text = labels[index]
		button.toggle_mode = true
		button.button_group = _group
		button.custom_minimum_size = option_minimum_size
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = index == selected
		button.pressed.connect(_on_option_pressed.bind(index))
		_buttons.append(button)
		_row.add_child(button)


## Chooses [param index] without reporting it.
func select(index: int) -> void:
	if index >= 0 and index < _buttons.size():
		_buttons[index].set_pressed_no_signal(true)


func selected() -> int:
	for index: int in _buttons.size():
		if _buttons[index].button_pressed:
			return index
	return -1


func option(index: int) -> Button:
	return _buttons[index]


func _on_option_pressed(index: int) -> void:
	option_chosen.emit(index)
