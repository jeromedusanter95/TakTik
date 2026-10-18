class_name ChatSheet
extends Control
## On phones, the chat slides up as a bottom sheet over a dimmed game. It
## closes with its close button, a tap on the backdrop, the back gesture or
## by dragging it down.

signal opened
signal closed

const OPEN_TIME: float = 0.32
const CLOSE_TIME: float = 0.22
const SHEET_HEIGHT: float = 520.0
## How far the sheet must be dragged down to close.
const CLOSE_DRAG: float = 80.0

var reduced_motion: bool = false

var _tween: Tween = null
var _drag_start: float = -1.0

@onready var _backdrop: PanelContainer = %Backdrop
@onready var _sheet: PanelContainer = %Sheet
@onready var _handle: Control = %Handle
@onready var _close_button: Button = %CloseButton
@onready var _body: VBoxContainer = %Body


func _ready() -> void:
	_close_button.pressed.connect(close)
	_backdrop.gui_input.connect(_on_backdrop_input)
	_handle.gui_input.connect(_on_handle_input)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Where the chat goes while the sheet holds it.
func body() -> VBoxContainer:
	return _body


func open() -> void:
	show()
	_sheet.offset_top = -SHEET_HEIGHT
	_stop()
	_tween = create_tween()
	var duration: float = 0.01 if reduced_motion else OPEN_TIME
	_backdrop.modulate.a = 0.0
	_sheet.position.y = size.y
	_tween.tween_property(_backdrop, "modulate:a", 1.0, duration)
	_tween.parallel().tween_property(_sheet, "position:y", size.y - SHEET_HEIGHT, duration).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	opened.emit()


func close() -> void:
	if not visible:
		return
	_stop()
	_tween = create_tween()
	var duration: float = 0.01 if reduced_motion else CLOSE_TIME
	_tween.tween_property(_backdrop, "modulate:a", 0.0, duration)
	_tween.parallel().tween_property(_sheet, "position:y", size.y, duration).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_IN)
	_tween.tween_callback(hide)
	closed.emit()


func is_open() -> bool:
	return visible


func _stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			close()


func _on_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		_drag_start = click.global_position.y if click.pressed else -1.0
	elif event is InputEventMouseMotion and _drag_start >= 0.0:
		var motion: InputEventMouseMotion = event
		var dragged: float = motion.global_position.y - _drag_start
		_sheet.position.y = size.y - SHEET_HEIGHT + maxf(0.0, dragged)
		if dragged > CLOSE_DRAG:
			_drag_start = -1.0
			close()
