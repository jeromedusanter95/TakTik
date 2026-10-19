class_name SectionHeading
extends HBoxContainer
## A rules page section's title, after its number in reading order.

## Such as "01"; never translated.
@export var number: String = ""
## The title, as a translation key.
@export var title: String = ""

@onready var _number: Label = %Number
@onready var _title: Label = %Title


func _ready() -> void:
	_number.text = number
	_title.text = title
