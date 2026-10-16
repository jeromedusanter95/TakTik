class_name HandoffScreen
extends Control
## Covers the Board while the device passes from one player to the other, so
## neither sees the other's Pieces.

signal continued

@onready var _title_label: Label = %TitleLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)


func present(title: String, summary: String) -> void:
	_title_label.text = title
	_summary_label.text = summary
	show()


func _on_continue_pressed() -> void:
	hide()
	continued.emit()
