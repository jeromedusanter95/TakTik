class_name OnlineMatch
extends Control
## A game against another Guest through the online server: enter the Lobby,
## find an Opponent there by Quick Match or Challenge, arrange the Army before
## the Setup Timer runs out, then play, always seeing the Board from this
## Guest's side, with the choice to Resign.

signal menu_requested

var _server_url: String = ""
## Returns a new WireSocket for each connection.
var _open_socket: Callable = Callable()
var _rng: RandomNumberGenerator = null
## Returns the milliseconds of a clock that never goes back.
var _ticks_msec: Callable = Callable()
var _nickname: String = ""
var _lobby: LobbyClient = null
var _session: OnlineSession = null
var _selected: Vector2i = BoardViewState.NO_SQUARE
var _notice: String = ""
## The Setup Timer's seconds on screen, to redraw only when they change.
var _shown_setup_seconds: int = OnlineSession.NO_SETUP_TIMER

@onready var _lobby_panel: LobbyPanel = %LobbyPanel
@onready var _status_label: Label = %StatusLabel
@onready var _menu_button: Button = %MenuButton
@onready var _board_view: BoardView = %BoardView
@onready var _info_label: Label = %InfoLabel
@onready var _graveyard_label: Label = %GraveyardLabel
@onready var _shuffle_button: Button = %ShuffleButton
@onready var _action_button: Button = %ActionButton
@onready var _resign_button: Button = %ResignButton
@onready var _resign_dialog: ConfirmationDialog = %ResignDialog
@onready var _rematch_button: Button = %RematchButton
@onready var _chat_button: Button = %ChatButton
@onready var _chat_menu: PopupMenu = %ChatMenu
@onready var _chat_label: Label = %ChatLabel


func _ready() -> void:
	_lobby_panel.enter_requested.connect(_enter_lobby)
	_lobby_panel.quick_match_requested.connect(_on_quick_match_requested)
	_lobby_panel.stop_waiting_requested.connect(_on_stop_waiting_requested)
	_lobby_panel.challenge_requested.connect(_on_challenge_requested)
	_lobby_panel.withdraw_requested.connect(_on_withdraw_requested)
	_lobby_panel.answer_requested.connect(_on_answer_requested)
	_lobby_panel.back_requested.connect(_on_menu_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_board_view.square_pressed.connect(_on_square_pressed)
	_shuffle_button.pressed.connect(_on_shuffle_pressed)
	_action_button.pressed.connect(_on_action_pressed)
	_rematch_button.pressed.connect(_on_rematch_pressed)
	_chat_button.pressed.connect(_on_chat_pressed)
	_chat_menu.id_pressed.connect(_on_chat_chosen)
	_resign_button.pressed.connect(_on_resign_pressed)
	_resign_dialog.confirmed.connect(_on_resign_confirmed)


func _process(_delta: float) -> void:
	if _lobby != null:
		_lobby.poll()
	if _session != null:
		_session.poll()
	if _session != null and _session.setup_seconds_left() != _shown_setup_seconds:
		_refresh()


## Opens on the nickname entry. [param server_url] is the server's WebSocket
## origin; [param open_socket] returns a new WireSocket each time it is called;
## [param ticks_msec] returns the milliseconds of a clock that never goes back,
## such as Time.get_ticks_msec.
func start(
	server_url: String, open_socket: Callable, rng: RandomNumberGenerator, ticks_msec: Callable
) -> void:
	_server_url = server_url
	_open_socket = open_socket
	_rng = rng
	_ticks_msec = ticks_msec
	_leave()
	_lobby_panel.show_entry("")


func _enter_lobby(nickname: String) -> void:
	_leave()
	_nickname = nickname
	_lobby = LobbyClient.new(_new_socket())
	_lobby.changed.connect(_on_lobby_changed)
	_lobby.paired.connect(_on_paired)
	_lobby.failed.connect(_on_lobby_failed)
	_lobby.challenge_ended.connect(_on_challenge_ended)
	_lobby.enter(_server_url, nickname)
	_lobby_panel.show_entering()


func _on_lobby_changed() -> void:
	if _lobby.has_entered():
		_lobby_panel.show_lobby(_lobby)


func _on_quick_match_requested() -> void:
	_lobby.join_quick_match()


func _on_stop_waiting_requested() -> void:
	_lobby.stop_waiting()


func _on_challenge_requested(guest_id: String) -> void:
	_lobby_panel.show_message("")
	_lobby.challenge(guest_id)


func _on_withdraw_requested() -> void:
	_lobby.withdraw_challenge()


func _on_answer_requested(guest_id: String, accept: bool) -> void:
	_lobby.answer_challenge(guest_id, accept)


func _on_challenge_ended(nickname: String, reason: String) -> void:
	_lobby_panel.show_message(OnlineMatchTexts.challenge_end(nickname, reason))


func _on_lobby_failed(reason: String) -> void:
	_lobby = null
	_lobby_panel.show_entry(OnlineMatchTexts.lobby_failure(reason))


func _on_paired(seat: PairedSeat) -> void:
	_lobby = null
	_join_game(seat)


## Leaves any game and takes [param seat] in a new one.
func _join_game(seat: PairedSeat) -> void:
	if _session != null:
		_session.leave()
	_selected = BoardViewState.NO_SQUARE
	_notice = ""
	_chat_label.text = ""
	_session = OnlineSession.new(_new_socket(), seat, _rng, _ticks_msec)
	_session.changed.connect(_refresh)
	_session.refused.connect(_on_refused)
	_session.quick_chat_received.connect(_on_quick_chat_received)
	_session.rematch_ready.connect(_join_game)
	_session.connect_to(_server_url)
	_lobby_panel.hide()


func _on_menu_pressed() -> void:
	_leave()
	menu_requested.emit()


func _on_refused(_reason: String) -> void:
	_notice = Translated.text(&"ONLINE_REFUSED")
	_refresh()


func _on_square_pressed(square: Vector2i) -> void:
	if _session == null:
		return
	match _session.phase():
		OnlineSession.Phase.ARRANGING:
			_press_during_setup(square)
		OnlineSession.Phase.PLAYING:
			_press_during_play(square)


func _press_during_setup(square: Vector2i) -> void:
	if not _session.setup().is_setup_square(square):
		return
	if _selected == BoardViewState.NO_SQUARE:
		_selected = square
	else:
		_session.swap_in_setup(_selected, square)
		_selected = BoardViewState.NO_SQUARE
	_refresh()


func _press_during_play(square: Vector2i) -> void:
	_notice = ""
	var is_own_piece: bool = _session.position().is_own_piece(square)
	if is_own_piece and square != _selected:
		_selected = square
	elif _selected != BoardViewState.NO_SQUARE and _session.play(Move.new(_selected, square)):
		_selected = BoardViewState.NO_SQUARE
	else:
		_selected = BoardViewState.NO_SQUARE
	_refresh()


func _on_shuffle_pressed() -> void:
	_session.shuffle_setup()
	_selected = BoardViewState.NO_SQUARE
	_refresh()


func _on_action_pressed() -> void:
	match _session.phase():
		OnlineSession.Phase.ARRANGING:
			_selected = BoardViewState.NO_SQUARE
			_session.confirm_setup()
		OnlineSession.Phase.DISCONNECTED:
			_session.reconnect()
		OnlineSession.Phase.OVER:
			_enter_lobby(_nickname)


func _on_rematch_pressed() -> void:
	_session.ask_for_rematch()


func _on_chat_pressed() -> void:
	_chat_menu.clear()
	for index: int in QuickChat.MESSAGES.size():
		_chat_menu.add_item(QuickChat.text(QuickChat.MESSAGES[index]), index)
	var button_rect: Rect2 = _chat_button.get_global_rect()
	_chat_menu.popup(Rect2i(Vector2i(button_rect.position) - Vector2i(0, 220), Vector2i(220, 0)))


func _on_chat_chosen(index: int) -> void:
	if _session != null and index >= 0 and index < QuickChat.MESSAGES.size():
		_session.send_quick_chat(QuickChat.MESSAGES[index])


func _on_quick_chat_received(sender: Side.Id, message: String) -> void:
	var name: String = (
		Translated.text(&"CHAT_YOU") if sender == _session.side() else _session.opponent()
	)
	_chat_label.text = Translated.text(&"CHAT_LINE", {"name": name, "message": QuickChat.text(message)})


func _on_resign_pressed() -> void:
	_resign_dialog.title = Translated.text(&"ONLINE_RESIGN_TITLE")
	_resign_dialog.dialog_text = Translated.text(
		&"ONLINE_RESIGN_CONFIRM", {"opponent": _session.opponent()}
	)
	_resign_dialog.ok_button_text = Translated.text(&"ONLINE_RESIGN")
	_resign_dialog.cancel_button_text = Translated.text(&"ONLINE_KEEP_PLAYING")
	_resign_dialog.popup_centered()


func _on_resign_confirmed() -> void:
	if _session == null:
		return
	_selected = BoardViewState.NO_SQUARE
	_session.resign()
	_refresh()


func _refresh() -> void:
	if _session == null:
		return
	_board_view.show_state(_board_state())
	_shown_setup_seconds = _session.setup_seconds_left()
	_status_label.text = OnlineMatchTexts.status(_session)
	_info_label.text = _notice if not _notice.is_empty() else OnlineMatchTexts.info(_session, _selected)
	_graveyard_label.text = OnlineMatchTexts.graveyards(_session)
	var phase: OnlineSession.Phase = _session.phase()
	_shuffle_button.visible = phase == OnlineSession.Phase.ARRANGING and not _session.is_awaiting_answer()
	_action_button.visible = _action_text(phase) != "" and not _session.is_awaiting_answer()
	_action_button.text = _action_text(phase)
	var can_resign: bool = (
		phase == OnlineSession.Phase.PLAYING and not _session.is_awaiting_answer()
	)
	_resign_button.visible = can_resign
	_rematch_button.visible = phase == OnlineSession.Phase.OVER
	_rematch_button.disabled = _session.has_asked_for_rematch()
	_rematch_button.text = OnlineMatchTexts.rematch_button(_session)
	_chat_button.visible = (
		phase != OnlineSession.Phase.CONNECTING and phase != OnlineSession.Phase.DISCONNECTED
	)
	if not can_resign and _resign_dialog.visible:
		_resign_dialog.hide()


func _board_state() -> BoardViewState:
	var state: BoardViewState = BoardViewState.new()
	state.board = _session.display_board()
	state.viewer = _session.side()
	state.reveal_all = _session.phase() == OnlineSession.Phase.OVER
	state.selected = _selected
	var last: PublicMoveEvent = _session.last_event()
	state.last_move = last.move if last != null else null
	if _selected != BoardViewState.NO_SQUARE:
		state.destinations = _session.legal_destinations(_selected)
	return state


func _action_text(phase: OnlineSession.Phase) -> String:
	match phase:
		OnlineSession.Phase.ARRANGING:
			return Translated.text(&"MATCH_READY")
		OnlineSession.Phase.DISCONNECTED:
			return Translated.text(&"ONLINE_RECONNECT")
		OnlineSession.Phase.OVER:
			return Translated.text(&"ONLINE_NEW_OPPONENT")
		_:
			return ""


func _new_socket() -> WireSocket:
	var socket: Variant = _open_socket.call()
	if socket is not WireSocket:
		push_error("open_socket must return a WireSocket")
		return null
	return socket


## Leaves the Lobby and any game.
func _leave() -> void:
	if _lobby != null:
		_lobby.leave()
		_lobby = null
	if _session != null:
		_session.leave()
		_session = null
