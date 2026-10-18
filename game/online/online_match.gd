class_name OnlineMatch
extends Control
## A game against another Guest through the online server, from taking the
## seat to the end of game: arrange the Army before the Setup Timer runs out,
## play with the Turn Timer, chat with Quick Chats, Resign, ask for a
## Rematch, and come back to the Lobby. The Board is always seen from this
## Guest's side.

## The Guest leaves the game for the Lobby.
signal lobby_requested

## How long a Move may wait for the referee before the top bar says the
## connection is slow.
const SLOW_AFTER_MSEC: int = 3_000
## How long the referee gives, to draw the timer rings in proportion.
const SETUP_SECONDS: int = 180
const TURN_SECONDS: int = 60
## Seconds before each automatic reconnection try.
const RETRY_DELAYS: Array[float] = [1.0, 2.0, 4.0, 8.0]

var _server_url: String = ""
## Returns a new WireSocket for each connection.
var _open_socket: Callable = Callable()
var _rng: RandomNumberGenerator = null
## Returns the milliseconds of a clock that never goes back.
var _ticks_msec: Callable = Callable()
var _nickname: String = ""
var _session: OnlineSession = null
## Keeps this Guest listed in the Lobby as in a game while they play.
var _presence: LobbyClient = null
var _selected: Vector2i = BoardViewState.NO_SQUARE
## The timer seconds on screen, redrawn only when they change.
var _shown_seconds_left: int = OnlineSession.NO_TIMER
## How many Moves the screen already shows, to animate only new ones.
var _shown_moves: int = 0
var _was_own_turn: bool = false
var _setup_announced: bool = false
var _random_setup_announced: bool = false
var _result_shown: bool = false
var _retry_index: int = 0
## The Move sent and not answered yet, and when it left, or null.
var _pending_move: Move = null
var _pending_since_msec: int = 0
var _shown_slow: bool = false
## Seconds until the next reconnection try, or a negative number for none.
var _retry_in: float = -1.0

@onready var _screen: MatchScreen = %MatchScreen


func _ready() -> void:
	_screen.set_chat_enabled(true)
	_screen.square_pressed.connect(_on_square_pressed)
	_screen.board_cancelled.connect(_on_board_cancelled)
	_screen.shuffle_pressed.connect(_on_shuffle_pressed)
	_screen.action_pressed.connect(_on_action_pressed)
	_screen.resign_confirmed.connect(_on_resign_confirmed)
	_screen.quit_requested.connect(_back_to_lobby)
	_screen.rematch_pressed.connect(_on_rematch_pressed)
	_screen.leave_pressed.connect(_back_to_lobby)
	_screen.quick_chat_chosen.connect(_on_quick_chat_chosen)
	_screen.connection_retry_pressed.connect(_on_retry_pressed)
	_screen.connection_leave_pressed.connect(_back_to_lobby)
	_screen.display_changed.connect(_refresh)


func _process(delta: float) -> void:
	if _presence != null:
		_presence.poll()
	if _session == null:
		return
	_session.poll()
	if _session == null:
		return
	if _retry_in >= 0.0:
		_retry_in -= delta
		if _retry_in < 0.0:
			_session.reconnect()
	if _seconds_left() != _shown_seconds_left or _is_slow() != _shown_slow:
		_refresh()


## [param server_url] is the server's WebSocket origin; [param open_socket]
## returns a new WireSocket each time it is called; [param ticks_msec]
## returns the milliseconds of a clock that never goes back, such as
## Time.get_ticks_msec.
func configure(
	server_url: String, open_socket: Callable, rng: RandomNumberGenerator, ticks_msec: Callable
) -> void:
	_server_url = server_url
	_open_socket = open_socket
	_rng = rng
	_ticks_msec = ticks_msec


func use_preferences(preferences: PlayerPreferences) -> void:
	_screen.use_preferences(preferences)


func use_sound(sound: SoundOutput) -> void:
	_screen.use_sound(sound)


func set_layout(layout: ScreenLayout.Id) -> void:
	_screen.set_layout(layout)


func set_phone(phone: bool) -> void:
	_screen.set_phone(phone)


## Takes [param seat] in a new game, as [param nickname].
func play(seat: PairedSeat, nickname: String) -> void:
	_nickname = nickname
	_join_game(seat)
	_presence = LobbyClient.new(_new_socket())
	_presence.failed.connect(_on_presence_failed)
	_presence.enter(_server_url, nickname, true)


## Leaves any game, and the Lobby listing.
func leave() -> void:
	_leave_game()
	if _presence != null:
		_presence.leave()
		_presence = null


func _leave_game() -> void:
	_retry_in = -1.0
	if _session != null:
		_session.leave()
		_session = null


## Leaves any game and takes [param seat] in a new one.
func _join_game(seat: PairedSeat) -> void:
	_leave_game()
	_selected = BoardViewState.NO_SQUARE
	_shown_moves = 0
	_was_own_turn = false
	_setup_announced = false
	_random_setup_announced = false
	_result_shown = false
	_pending_move = null
	_retry_index = 0
	_screen.close_overlays()
	_screen.clear_chat()
	_screen.show_journal(PackedStringArray())
	_screen.set_resign_allowed(false)
	_session = OnlineSession.new(_new_socket(), seat, _rng, _ticks_msec)
	_session.changed.connect(_on_session_changed)
	_session.refused.connect(_on_refused)
	_session.quick_chat_received.connect(_on_quick_chat_received)
	_session.rematch_ready.connect(_join_game)
	_session.connect_to(_server_url)


## Being listed is a courtesy to the others; the game goes on without it.
func _on_presence_failed(_reason: String) -> void:
	_presence = null


func _back_to_lobby() -> void:
	leave()
	_screen.close_overlays()
	lobby_requested.emit()


func _on_session_changed() -> void:
	if not _session.is_awaiting_answer():
		_pending_move = null
	_show_new_moves()
	_announce_setup()
	_follow_connection()
	_refresh()
	_announce_turn()


func _on_refused(_reason: String) -> void:
	_screen.add_system(Translated.text(&"ONLINE_REFUSED"))
	_refresh()


func _on_square_pressed(square: Vector2i) -> void:
	if _session == null:
		return
	match _session.phase():
		OnlineSession.Phase.ARRANGING:
			_press_during_setup(square)
		OnlineSession.Phase.PLAYING:
			_press_during_play(square)


func _on_board_cancelled() -> void:
	_selected = BoardViewState.NO_SQUARE
	_refresh()


func _press_during_setup(square: Vector2i) -> void:
	if _session.is_awaiting_answer() or not _session.setup().is_setup_square(square):
		return
	if _selected == BoardViewState.NO_SQUARE:
		_selected = square
		_refresh()
		return
	var first: Vector2i = _selected
	_selected = BoardViewState.NO_SQUARE
	if first == square:
		_refresh()
		return
	_session.swap_in_setup(first, square)
	_screen.play_swap(first, square)


func _press_during_play(square: Vector2i) -> void:
	var is_own_piece: bool = _session.position().is_own_piece(square)
	if is_own_piece and square != _selected:
		_selected = square
	elif _selected != BoardViewState.NO_SQUARE and _session.play(Move.new(_selected, square)):
		_pending_move = Move.new(_selected, square)
		_pending_since_msec = _now_msec()
		_selected = BoardViewState.NO_SQUARE
	else:
		_selected = BoardViewState.NO_SQUARE
	_refresh()


func _on_shuffle_pressed() -> void:
	var before: Board = _session.display_board()
	_selected = BoardViewState.NO_SQUARE
	_session.shuffle_setup()
	_screen.play_shuffle(before)


func _on_action_pressed() -> void:
	if _session != null and _session.phase() == OnlineSession.Phase.ARRANGING:
		_selected = BoardViewState.NO_SQUARE
		_session.confirm_setup()


func _on_rematch_pressed() -> void:
	_session.ask_for_rematch()


func _on_resign_confirmed() -> void:
	if _session == null:
		return
	_selected = BoardViewState.NO_SQUARE
	_session.resign()
	_refresh()


func _on_quick_chat_chosen(message: String) -> void:
	if _session != null:
		_session.send_quick_chat(message)


func _on_quick_chat_received(sender: Side.Id, message: String) -> void:
	var is_you: bool = sender == _session.side()
	var author: String = Translated.text(&"CHAT_YOU") if is_you else _session.opponent()
	_screen.add_chat(author, QuickChat.text(message), is_you)


func _on_retry_pressed() -> void:
	_retry_index = 0
	_retry_in = -1.0
	_session.reconnect()


## Animates a Move that just arrived, and keeps the chat and Journal up to
## date with every Move.
func _show_new_moves() -> void:
	var history: Array[PublicMoveEvent] = _session.history()
	if history.size() == _shown_moves:
		return
	var just_played: bool = history.size() == _shown_moves + 1
	for index: int in range(_shown_moves, history.size()):
		if history[index].has_fight:
			_screen.add_fight(OnlineMatchTexts.fight_line(history[index]))
	_shown_moves = history.size()
	var lines: PackedStringArray = []
	for event: PublicMoveEvent in history:
		lines.append(MatchNarrator.describe_event(event))
	_screen.show_journal(lines)
	if just_played:
		_refresh()
		_screen.play_move(history[history.size() - 1])


func _announce_setup() -> void:
	var phase: OnlineSession.Phase = _session.phase()
	if phase == OnlineSession.Phase.ARRANGING and not _setup_announced:
		_setup_announced = true
		_screen.add_system(Translated.text(&"CHAT_SETUP_TIME", {"minutes": floori(SETUP_SECONDS / 60.0)}))
	if _session.was_setup_arranged_at_random() and not _random_setup_announced:
		_random_setup_announced = true
		_screen.add_system(Translated.text(&"ONLINE_SETUP_TIMER_RAN_OUT"))


func _announce_turn() -> void:
	var own_turn: bool = _session.phase() == OnlineSession.Phase.PLAYING and _session.is_own_turn()
	if own_turn and not _was_own_turn:
		_screen.play_turn_banner()
	if not _session.is_awaiting_answer():
		_was_own_turn = own_turn


## Tries to reconnect by itself after a drop, waiting longer each time, then
## lets the Guest choose.
func _follow_connection() -> void:
	match _session.phase():
		OnlineSession.Phase.DISCONNECTED:
			if _session.disconnection_reason() == "seat_taken_elsewhere":
				_retry_in = -1.0
				_screen.show_connection(
					Translated.text(&"ONLINE_SEAT_TAKEN"), "", false, "", Translated.text(&"ONLINE_NEW_OPPONENT")
				)
			elif _retry_index < RETRY_DELAYS.size():
				_retry_in = RETRY_DELAYS[_retry_index]
				_retry_index += 1
				_screen.show_connection(
					Translated.text(&"ONLINE_RECONNECTING"), Translated.text(&"ONLINE_RECONNECT_DETAIL"), true,
					"", Translated.text(&"ONLINE_NEW_OPPONENT")
				)
			else:
				_retry_in = -1.0
				_screen.show_connection(
					Translated.text(&"ONLINE_DISCONNECTED"), "", false,
					Translated.text(&"ONLINE_RECONNECT"), Translated.text(&"ONLINE_NEW_OPPONENT")
				)
		OnlineSession.Phase.CONNECTING:
			pass
		_:
			_retry_index = 0
			_retry_in = -1.0
			_screen.hide_connection()


func _refresh() -> void:
	if _session == null:
		return
	var phase: OnlineSession.Phase = _session.phase()
	_screen.set_phase(_screen_phase(phase))
	_screen.show_subtitle(Translated.text(&"SUBTITLE_ONLINE", {"opponent": _session.opponent()}))
	_screen.show_board(_board_state())
	_screen.set_resign_allowed(phase == OnlineSession.Phase.PLAYING and not _session.is_awaiting_answer())
	_screen.set_chips_enabled(phase != OnlineSession.Phase.CONNECTING and phase != OnlineSession.Phase.DISCONNECTED)
	_show_players()
	_show_status()
	_show_beside_board()
	_show_board_actions(phase)
	if phase == OnlineSession.Phase.OVER:
		_show_result()


func _screen_phase(phase: OnlineSession.Phase) -> MatchScreen.Phase:
	if phase == OnlineSession.Phase.OVER:
		return MatchScreen.Phase.OVER
	return MatchScreen.Phase.PLAY if _session.position() != null else MatchScreen.Phase.SETUP


func _show_players() -> void:
	var own: Side.Id = _session.side()
	var opponent: Side.Id = Side.opponent(own)
	_screen.show_player(MatchScreen.Slot.YOU, _nickname, own, true)
	_screen.show_player(MatchScreen.Slot.OPPONENT, _session.opponent(), opponent, false)
	_screen.show_graveyard(MatchScreen.Slot.YOU, _session.graveyard(own))
	_screen.show_graveyard(MatchScreen.Slot.OPPONENT, _session.graveyard(opponent))
	_screen.show_player_status(MatchScreen.Slot.YOU, OnlineMatchTexts.own_status(_session))
	_screen.show_player_status(MatchScreen.Slot.OPPONENT, OnlineMatchTexts.opponent_status(_session))
	var active: MatchScreen.Slot = MatchScreen.Slot.NONE
	var fraction: float = -1.0
	if _session.phase() == OnlineSession.Phase.PLAYING:
		var own_turn: bool = _session.position().side_to_move() == own
		active = MatchScreen.Slot.YOU if own_turn else MatchScreen.Slot.OPPONENT
		var seconds: int = _session.turn_seconds_left()
		fraction = float(seconds) / TURN_SECONDS if seconds != OnlineSession.NO_TIMER else -1.0
	_screen.show_turn(active, fraction)


func _show_status() -> void:
	var phase: OnlineSession.Phase = _session.phase()
	var text: String = OnlineMatchTexts.status(_session)
	_shown_seconds_left = _seconds_left()
	if phase == OnlineSession.Phase.OVER:
		_screen.show_finished(text)
		_screen.hide_timer()
		return
	var opponent_turn: bool = (
		phase == OnlineSession.Phase.PLAYING and not _session.is_own_turn() and not _session.is_awaiting_answer()
	)
	_shown_slow = _is_slow()
	if _shown_slow:
		text = Translated.text(&"ONLINE_SLOW")
	_screen.show_status(text, UiTokens.AMBER_400 if _shown_slow else (UiTokens.GREEN_400 if opponent_turn else Color.TRANSPARENT), opponent_turn)
	var setup_seconds: int = _session.setup_seconds_left()
	var turn_seconds: int = _session.turn_seconds_left()
	if setup_seconds != OnlineSession.NO_TIMER:
		_screen.show_timer(setup_seconds, SETUP_SECONDS, UiTokens.GOLD_500)
	elif turn_seconds != OnlineSession.NO_TIMER:
		_screen.show_timer(turn_seconds, TURN_SECONDS, UiTokens.GREEN_400 if opponent_turn else UiTokens.GOLD_500)
	else:
		_screen.hide_timer()


func _show_beside_board() -> void:
	if _session.position() == null:
		var piece: Piece = _session.display_board().piece_at(_selected)
		if piece != null:
			_screen.show_selected_piece(piece.type, piece.side, _selected)
		else:
			_screen.show_no_selected_piece()
		return
	var fight: PublicMoveEvent = _last_fight()
	if fight != null:
		_screen.show_last_fight(fight)
	else:
		_screen.show_no_fight()


func _show_board_actions(phase: OnlineSession.Phase) -> void:
	match phase:
		OnlineSession.Phase.ARRANGING:
			if _session.is_awaiting_answer():
				_screen.show_board_actions(true, Translated.text(&"ONLINE_WAITING_SETUP", {"opponent": _session.opponent()}), false)
			else:
				_screen.show_board_actions(true, Translated.text(&"MATCH_READY"), true)
		OnlineSession.Phase.WAITING_FOR_OPPONENT_SETUP:
			_screen.show_board_actions(false, Translated.text(&"ONLINE_WAITING_SETUP", {"opponent": _session.opponent()}), false)
		_:
			_screen.show_board_actions(false, "", false)


func _show_result() -> void:
	if not _result_shown:
		_result_shown = true
		var names: Dictionary[Side.Id, String] = {
			_session.side(): _nickname,
			Side.opponent(_session.side()): _session.opponent(),
		}
		var view: MatchResultView = MatchResultView.of(
			_session.result(), _session.side(), false, _last_fight(),
			_session.graveyard(Side.Id.RED), _session.graveyard(Side.Id.GREEN), names
		)
		view.primary_label = OnlineMatchTexts.rematch_button(_session)
		view.secondary_label = Translated.text(&"ONLINE_NEW_OPPONENT")
		_screen.show_result(view)
	_screen.show_rematch(OnlineMatchTexts.rematch_button(_session), not _session.has_asked_for_rematch())
	_screen.show_rematch_notice(OnlineMatchTexts.rematch_notice(_session))


func _board_state() -> BoardViewState:
	var state: BoardViewState = BoardViewState.new()
	state.board = _session.display_board()
	state.viewer = _session.side()
	state.reveal_all = _session.phase() == OnlineSession.Phase.OVER
	state.selected = _selected
	var last: PublicMoveEvent = _session.last_event()
	state.last_move = last.move if last != null else null
	state.pending_move = _pending_move
	if _session.position() == null:
		state.cover_enemy_zone = true
		state.enemy_zone_label = Translated.text(&"ZONE_HIDDEN", {"name": _session.opponent()})
	elif _selected != BoardViewState.NO_SQUARE:
		state.destinations = _session.legal_destinations(_selected)
	return state


## True once a Move has waited for the referee longer than SLOW_AFTER_MSEC.
func _is_slow() -> bool:
	return _pending_move != null and _now_msec() - _pending_since_msec >= SLOW_AFTER_MSEC


func _now_msec() -> int:
	var now: Variant = _ticks_msec.call()
	return now if now is int else 0


func _last_fight() -> PublicMoveEvent:
	var history: Array[PublicMoveEvent] = _session.history()
	for index: int in range(history.size() - 1, -1, -1):
		if history[index].has_fight:
			return history[index]
	return null


## A number that changes whenever a countdown on screen does: the Setup or
## Turn Timer (at most one runs, the other is OnlineSession.NO_TIMER) and an
## away Opponent's Forfeit.
func _seconds_left() -> int:
	var timer: int = maxi(_session.setup_seconds_left(), _session.turn_seconds_left())
	return timer * 10_000 + _session.opponent_forfeit_seconds_left()


func _new_socket() -> WireSocket:
	var socket: Variant = _open_socket.call()
	if socket is not WireSocket:
		push_error("open_socket must return a WireSocket")
		return null
	return socket
