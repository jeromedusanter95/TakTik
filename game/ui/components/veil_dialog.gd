class_name VeilDialog
extends Control
## A card over a dimmed screen: a title, a line of detail, an optional
## spinner and up to two buttons. Used to confirm a Resign and while the
## connection comes back.

signal primary_pressed
signal secondary_pressed

@onready var _title_label: Label = %TitleLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _spinner: Spinner = %Spinner
@onready var _primary_button: Button = %PrimaryButton
@onready var _secondary_button: Button = %SecondaryButton


func _ready() -> void:
	_primary_button.pressed.connect(_on_primary_pressed)
	_secondary_button.pressed.connect(_on_secondary_pressed)
	hide()


## Shows the dialog. An empty button text hides that button; [param danger]
## draws the first button red.
func present(
		title: String,
		detail: String,
		busy: bool,
		primary_text: String,
		secondary_text: String,
		danger: bool = false,
) -> void:
	_title_label.text = title
	_detail_label.text = detail
	_detail_label.visible = not detail.is_empty()
	_spinner.visible = busy
	_primary_button.text = primary_text
	_primary_button.visible = not primary_text.is_empty()
	_primary_button.theme_type_variation = &"DangerButton" if danger else &"GoldButton"
	_secondary_button.text = secondary_text
	_secondary_button.visible = not secondary_text.is_empty()
	show()
	if _secondary_button.visible:
		_secondary_button.grab_focus()
	elif _primary_button.visible:
		_primary_button.grab_focus()


func _on_primary_pressed() -> void:
	hide()
	primary_pressed.emit()


func _on_secondary_pressed() -> void:
	hide()
	secondary_pressed.emit()
