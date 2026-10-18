class_name OnlineMatch
extends Control
## A game against another Guest through the online server: find an Opponent
## with Quick Match, arrange the Army, then play, always seeing the Board from
## this Guest's side, with the choice to Resign.

signal menu_requested

var _server_url: String = ""
## Returns a new WireSocket for each connection.
var _open_socket: Callable = Callable()
var _rng: RandomNumberGenerator = null
var _search: QuickMatchSearch = null
var _session: OnlineSession = null
var _selected: Vector2i = BoardViewState.NO_SQUARE
var _notice: String = ""

@onready var _find_panel: FindOpponentPanel = %FindOpponentPanel
@onready var _status_label: Label = %StatusLabel
@onready var _menu_button: Button = %MenuButton
@onready var _board_view: BoardView = %BoardView
@onready var _info_label: Label = %InfoLabel
@onready var _graveyard_label: Label = %GraveyardLabel
@onready var _shuffle_button: Button = %ShuffleButton
@onready var _action_button: Button = %ActionButton
@onready var _resign_button: Button = %ResignButton
@onready var _resign_dialog: ConfirmationDialog = %ResignDialog


func _ready() -> void:
	_find_panel.find_requested.connect(_on_find_requested)
	_find_panel.cancel_requested.connect(_on_cancel_requested)
	_find_panel.back_requested.connect(_on_menu_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_board_view.square_pressed.connect(_on_square_pressed)
	_shuffle_button.pressed.connect(_on_shuffle_pressed)
	_action_button.pressed.connect(_on_action_pressed)
	_resign_button.pressed.connect(_on_resign_pressed)
	_resign_dialog.confirmed.connect(_on_resign_confirmed)


func _process(_delta: float) -> void:
	if _search != null:
		_search.poll()
	if _session != null:
		_session.poll()


## Opens on the nickname entry. [param server_url] is the server's WebSocket
## origin; [param open_socket] returns a new WireSocket each time it is called.
func start(server_url: String, open_socket: Callable, rng: RandomNumberGenerator) -> void:
	_server_url = server_url
	_open_socket = open_socket
	_rng = rng
	_leave()
	_find_panel.show_entry("")


func _on_find_requested(nickname: String) -> void:
	_search = QuickMatchSearch.new(_new_socket())
	_search.paired.connect(_on_paired)
	_search.failed.connect(_on_search_failed)
	_search.start(_server_url, nickname)
	_find_panel.show_searching()


func _on_cancel_requested() -> void:
	_leave()
	_find_panel.show_entry("")


func _on_search_failed(reason: String) -> void:
	_search = null
	_find_panel.show_entry(OnlineMatchTexts.search_failure(reason))


func _on_paired(seat: PairedSeat) -> void:
	_search = null
	_selected = BoardViewState.NO_SQUARE
	_notice = ""
	_session = OnlineSession.new(_new_socket(), seat, _rng)
	_session.changed.connect(_refresh)
	_session.refused.connect(_on_refused)
	_session.connect_to(_server_url)
	_find_panel.hide()


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
			_leave()
			_find_panel.show_entry("")


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


## Stops any search and leaves any game.
func _leave() -> void:
	if _search != null:
		_search.cancel()
		_search = null
	if _session != null:
		_session.leave()
		_session = null
