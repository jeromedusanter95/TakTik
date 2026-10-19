class_name RuleRow
extends PanelContainer
## One rule in one sentence, after an icon in a circle. A highlighted row
## marks an exception.

## The rule's icon, tinted gold.
@export var icon: Texture2D = null
## The rule's sentence, as a translation key.
@export var text: String = ""
@export var highlighted: bool = false

@onready var _icon: UiIcon = %Icon
@onready var _label: Label = %TextLabel


func _ready() -> void:
	theme_type_variation = &"RowHighlight" if highlighted else &"Row"
	_icon.texture = icon
	_label.text = text
