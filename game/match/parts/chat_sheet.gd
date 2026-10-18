class_name ChatSheet
extends Control
## On phones, the chat slides up as a bottom sheet over a dimmed game; on
## tablets, it slides in from the right as a drawer. It
## closes with its close button, a tap on the backdrop, the back gesture or
## by dragging it down.

signal opened
signal closed

const OPEN_TIME: float = 0.32
const CLOSE_TIME: float = 0.22
const SHEET_HEIGHT: float = 520.0
const DRAWER_WIDTH: float = 360.0
## How far the sheet must be dragged down to close.
const CLOSE_DRAG: float = 80.0

var reduced_motion: bool = false

var _tween: Tween = null
var _drag_start: float = -1.0
## A drawer from the right on tablets, a sheet from the bottom on phones.
var _side: bool = false

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


## Slides in from the right, [param side], or up from the bottom.
func set_side_drawer(side: bool) -> void:
	_side = side
	_handle.visible = not side
	_sheet.theme_type_variation = &"Drawer" if side else &"Sheet"
	if side:
		_sheet.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		_sheet.offset_left = -DRAWER_WIDTH
	else:
		_sheet.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_sheet.offset_top = -SHEET_HEIGHT


func open() -> void:
	show()
	set_side_drawer(_side)
	_stop()
	_tween = create_tween()
	var duration: float = 0.01 if reduced_motion else OPEN_TIME
	_backdrop.modulate.a = 0.0
	var property: String = "position:x" if _side else "position:y"
	var rest: float = size.x - DRAWER_WIDTH if _side else size.y - SHEET_HEIGHT
	_sheet.position = Vector2(size.x, 0.0) if _side else Vector2(0.0, size.y)
	_tween.tween_property(_backdrop, "modulate:a", 1.0, duration)
	_tween.parallel().tween_property(_sheet, property, rest, duration).set_trans(
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
	var property: String = "position:x" if _side else "position:y"
	var away: float = size.x if _side else size.y
	_tween.parallel().tween_property(_sheet, property, away, duration).set_trans(
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


## A tap on the backdrop closes the sheet, once it has finished sliding in,
## so the tap that opened it never closes it again.
func _on_backdrop_input(event: InputEvent) -> void:
	if _tween != null and _tween.is_running():
		return
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
