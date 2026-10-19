class_name WinCard
extends PanelContainer
## One way to win: a picture, a title and a paragraph.

@export var way: WinVisual.Way = WinVisual.Way.CAPTURE
## Translation keys.
@export var title: String = ""
@export var body: String = ""

@onready var _visual: WinVisual = %Visual
@onready var _title: Label = %Title
@onready var _body: Label = %Body


func _ready() -> void:
	_visual.way = way
	_title.text = title
	_body.text = body


func set_adapted(adapted: bool) -> void:
	_visual.set_adapted(adapted)
