class_name StepCard
extends PanelContainer
## One step of a game, in order: a gold number badge, a title, a paragraph
## and an optional rule in a sunken box.

@export var number: String = ""
## Translation keys; an empty note hides its box.
@export var title: String = ""
@export var body: String = ""
@export var note: String = ""

@onready var _number: Label = %Number
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _note_box: PanelContainer = %NoteBox
@onready var _note: Label = %Note


func _ready() -> void:
	_number.text = number
	_title.text = title
	_body.text = body
	_note.text = note
	_note_box.visible = not note.is_empty()
