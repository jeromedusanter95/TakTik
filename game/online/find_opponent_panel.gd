class_name FindOpponentPanel
extends Control
## Where a Guest chooses a nickname and looks for an Opponent through Quick
## Match. It only collects the request and shows how the search goes.

signal find_requested(nickname: String)
signal cancel_requested
signal back_requested

@onready var _nickname_edit: LineEdit = %NicknameEdit
@onready var _find_button: Button = %FindButton
@onready var _cancel_button: Button = %CancelButton
@onready var _back_button: Button = %BackButton
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	_nickname_edit.max_length = Nickname.MAX_LENGTH
	_nickname_edit.text_changed.connect(_on_nickname_changed)
	_nickname_edit.text_submitted.connect(_on_nickname_submitted)
	_find_button.pressed.connect(_on_find_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	show_entry("")


## Ready for a nickname, with [param message] shown when not empty.
func show_entry(message: String) -> void:
	_nickname_edit.editable = true
	_find_button.visible = true
	_cancel_button.visible = false
	_message_label.text = message
	_refresh_find_button()
	show()


func show_searching() -> void:
	_nickname_edit.editable = false
	_find_button.visible = false
	_cancel_button.visible = true
	_message_label.text = Translated.text(&"ONLINE_SEARCHING")
	show()


func _refresh_find_button() -> void:
	_find_button.disabled = Nickname.cleaned(_nickname_edit.text).is_empty()


func _request_find() -> void:
	var nickname: String = Nickname.cleaned(_nickname_edit.text)
	if nickname.is_empty() or not _find_button.visible:
		return
	find_requested.emit(nickname)


func _on_nickname_changed(_text: String) -> void:
	_refresh_find_button()


func _on_nickname_submitted(_text: String) -> void:
	_request_find()


func _on_find_pressed() -> void:
	_request_find()


func _on_cancel_pressed() -> void:
	cancel_requested.emit()


func _on_back_pressed() -> void:
	back_requested.emit()
