class_name LobbyPanel
extends Control
## The Lobby as a Guest sees it: first a nickname to enter with, then the other
## Guests to Challenge, the Challenges received and Quick Match. It only shows
## a LobbyClient and reports what the Guest asks for.

signal enter_requested(nickname: String)
signal quick_match_requested
signal stop_waiting_requested
signal challenge_requested(guest_id: String)
signal withdraw_requested
signal answer_requested(guest_id: String, accept: bool)
signal back_requested

const ROW_FONT_SIZE: int = 20
const ROW_BUTTON_SIZE: Vector2 = Vector2(150, 48)

var _waiting: bool = false

@onready var _entry_section: VBoxContainer = %EntrySection
@onready var _nickname_edit: LineEdit = %NicknameEdit
@onready var _enter_button: Button = %EnterButton
@onready var _lobby_section: VBoxContainer = %LobbySection
@onready var _quick_match_button: Button = %QuickMatchButton
@onready var _challenge_row: HBoxContainer = %ChallengeRow
@onready var _challenge_label: Label = %ChallengeLabel
@onready var _withdraw_button: Button = %WithdrawButton
@onready var _challengers_list: VBoxContainer = %ChallengersList
@onready var _guest_list: VBoxContainer = %GuestList
@onready var _message_label: Label = %MessageLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_nickname_edit.max_length = Nickname.MAX_LENGTH
	_nickname_edit.text_changed.connect(_on_nickname_changed)
	_nickname_edit.text_submitted.connect(_on_nickname_submitted)
	_enter_button.pressed.connect(_on_enter_pressed)
	_quick_match_button.pressed.connect(_on_quick_match_pressed)
	_withdraw_button.pressed.connect(_on_withdraw_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	show_entry("")


## Ready for a nickname, with [param message] shown when not empty.
func show_entry(message: String) -> void:
	_entry_section.visible = true
	_lobby_section.visible = false
	_nickname_edit.editable = true
	_enter_button.visible = true
	_message_label.text = message
	_refresh_enter_button()
	show()


## Waiting for the server to let this Guest in.
func show_entering() -> void:
	_nickname_edit.editable = false
	_enter_button.visible = false
	_message_label.text = Translated.text(&"LOBBY_ENTERING")
	show()


## Shows where [param client] stands in the Lobby.
func show_lobby(client: LobbyClient) -> void:
	_entry_section.visible = false
	_lobby_section.visible = true
	_waiting = client.is_waiting()
	_quick_match_button.text = Translated.text(&"LOBBY_STOP_WAITING" if _waiting else &"LOBBY_QUICK_MATCH")
	var challenged: ListedGuest = client.challenged_guest()
	_challenge_row.visible = challenged != null
	if challenged != null:
		_challenge_label.text = Translated.text(&"LOBBY_CHALLENGE_SENT", {"nickname": challenged.nickname})
	_show_challengers(client.challengers())
	_show_guests(client.guests(), challenged)
	if _waiting:
		_message_label.text = Translated.text(&"LOBBY_WAITING")
	show()


func show_message(message: String) -> void:
	_message_label.text = message


func _show_challengers(challengers: Array[ListedGuest]) -> void:
	_clear(_challengers_list)
	for challenger: ListedGuest in challengers:
		var row: HBoxContainer = _row(Translated.text(&"LOBBY_CHALLENGED_BY", {"nickname": challenger.nickname}))
		row.add_child(_row_button(Translated.text(&"LOBBY_ACCEPT"), _on_answer_pressed.bind(challenger.guest_id, true)))
		row.add_child(_row_button(Translated.text(&"LOBBY_DECLINE"), _on_answer_pressed.bind(challenger.guest_id, false)))
		_challengers_list.add_child(row)


func _show_guests(guests: Array[ListedGuest], challenged: ListedGuest) -> void:
	_clear(_guest_list)
	if guests.is_empty():
		_guest_list.add_child(_row(Translated.text(&"LOBBY_EMPTY")))
		return
	for guest: ListedGuest in guests:
		var name: String = guest.nickname
		if guest.waiting:
			name = Translated.text(&"LOBBY_GUEST_WAITING", {"nickname": guest.nickname})
		var row: HBoxContainer = _row(name)
		var button: Button = _row_button(Translated.text(&"LOBBY_CHALLENGE"), _on_challenge_pressed.bind(guest.guest_id))
		button.disabled = challenged != null and challenged.guest_id == guest.guest_id
		row.add_child(button)
		_guest_list.add_child(row)


func _row(text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(label)
	return row


func _row_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = ROW_BUTTON_SIZE
	button.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.add_child(PressScaleFeedback.new())
	button.pressed.connect(on_pressed)
	return button


## Removes the rows at once, so a refresh never shows stale ones.
func _clear(list: Container) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _refresh_enter_button() -> void:
	_enter_button.disabled = Nickname.cleaned(_nickname_edit.text).is_empty()


func _request_enter() -> void:
	var nickname: String = Nickname.cleaned(_nickname_edit.text)
	if nickname.is_empty() or not _enter_button.visible:
		return
	enter_requested.emit(nickname)


func _on_nickname_changed(_text: String) -> void:
	_refresh_enter_button()


func _on_nickname_submitted(_text: String) -> void:
	_request_enter()


func _on_enter_pressed() -> void:
	_request_enter()


func _on_quick_match_pressed() -> void:
	if _waiting:
		stop_waiting_requested.emit()
	else:
		quick_match_requested.emit()


func _on_withdraw_pressed() -> void:
	withdraw_requested.emit()


func _on_challenge_pressed(guest_id: String) -> void:
	challenge_requested.emit(guest_id)


func _on_answer_pressed(guest_id: String, accept: bool) -> void:
	answer_requested.emit(guest_id, accept)


func _on_back_pressed() -> void:
	back_requested.emit()
