class_name GameMenu
extends Control
## The in-game menu over a dimmed screen: resume, resign when allowed, the
## player's preferences, and quit.

signal resign_pressed
signal quit_pressed

@onready var _resume_button: Button = %ResumeButton
@onready var _resign_button: Button = %ResignButton
@onready var _quit_button: Button = %QuitButton
@onready var _preference_rows: PreferenceRows = %PreferenceRows


func _ready() -> void:
	_resume_button.pressed.connect(close)
	_resign_button.pressed.connect(_on_resign_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func use_preferences(preferences: PlayerPreferences) -> void:
	_preference_rows.use_preferences(preferences)


func open(can_resign: bool) -> void:
	_resign_button.visible = can_resign
	show()
	_resume_button.grab_focus()


func close() -> void:
	hide()


func _on_resign_pressed() -> void:
	close()
	resign_pressed.emit()


func _on_quit_pressed() -> void:
	close()
	quit_pressed.emit()
