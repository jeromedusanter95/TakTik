class_name GameMenu
extends Control
## The in-game menu over a dimmed screen: resume, resign when allowed, the
## player's preferences, and quit.

signal resign_pressed
signal quit_pressed
## The player hid or showed the Opponent's messages for this game.
signal chat_hidden_changed(hidden: bool)

@onready var _resume_button: Button = %ResumeButton
@onready var _resign_button: Button = %ResignButton
@onready var _quit_button: Button = %QuitButton
@onready var _preference_rows: PreferenceRows = %PreferenceRows
@onready var _chat_row: HBoxContainer = %ChatRow
@onready var _hide_chat: SegmentedControl = %HideChat


func _ready() -> void:
	_resume_button.pressed.connect(close)
	_resign_button.pressed.connect(_on_resign_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_hide_chat.show_options(["PREFERENCE_NO", "PREFERENCE_YES"], 0)
	_hide_chat.option_chosen.connect(_on_hide_chat_chosen)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func use_preferences(preferences: PlayerPreferences) -> void:
	_preference_rows.use_preferences(preferences)


## Opens the menu; [param has_chat] offers to hide the Opponent's messages,
## shown as [param chat_hidden].
func open(can_resign: bool, has_chat: bool = false, chat_hidden: bool = false) -> void:
	_resign_button.visible = can_resign
	_chat_row.visible = has_chat
	_hide_chat.select(1 if chat_hidden else 0)
	show()
	_resume_button.grab_focus()


func close() -> void:
	hide()


func _on_hide_chat_chosen(index: int) -> void:
	chat_hidden_changed.emit(index == 1)


func _on_resign_pressed() -> void:
	close()
	resign_pressed.emit()


func _on_quit_pressed() -> void:
	close()
	quit_pressed.emit()
