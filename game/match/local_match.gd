class_name LocalMatch
extends Control
## A game on this device. Two people take turns and the Board is covered while
## the device changes hands; a person against a Bot always sees the Board from
## their own side and watches the Bot answer each Move.

signal menu_requested

## The shortest time a Bot's turn lasts on screen, so a person sees that the
## Bot is answering even when it decides at once.
@export var minimum_bot_turn_seconds: float = 0.6

var _create_session: Callable = Callable()
var _session: MatchSession = null
var _preferences: PlayerPreferences = null
## The Bot's name, or empty when two people share the device.
var _opponent_name: String = ""
## The player currently looking at the screen. With two people it stays the
## mover after a Move until the device is handed over.
var _viewer: Side.Id = Side.Id.RED
var _selected: Vector2i = BoardViewState.NO_SQUARE
var _turn_finished: bool = false
## The last Move that caused a Fight, or null.
var _last_fight: PublicMoveEvent = null
var _bot_thinking: BotThinking = null
var _bot_turn_elapsed: float = 0.0
var _bot_turn_started_msec: int = 0
var _bot_slowest_step_msec: int = 0
var _bot_busy_msec: int = 0
var _bot_thinking_frames: int = 0

@onready var _screen: MatchScreen = %MatchScreen
@onready var _handoff_screen: HandoffScreen = %HandoffScreen


func _ready() -> void:
	_screen.set_chat_enabled(false)
	_screen.set_resign_allowed(false)
	_screen.square_pressed.connect(_on_square_pressed)
	_screen.board_cancelled.connect(_on_board_cancelled)
	_screen.shuffle_pressed.connect(_on_shuffle_pressed)
	_screen.action_pressed.connect(_on_action_pressed)
	_screen.quit_requested.connect(_on_quit_requested)
	_screen.rematch_pressed.connect(_start_new_game)
	_screen.leave_pressed.connect(_on_quit_requested)
	_screen.display_changed.connect(_refresh)
	_handoff_screen.continued.connect(_on_handoff_continued)


## Steps the Bot's search once per frame, then plays its Move.
func _process(delta: float) -> void:
	if _bot_thinking == null:
		return
	_bot_turn_elapsed += delta
	if not _bot_thinking.is_done():
		_step_bot_thinking()
		return
	if _bot_turn_elapsed < minimum_bot_turn_seconds:
		return
	var move: Move = _bot_thinking.chosen_move()
	_bot_thinking = null
	var record: MoveRecord = _session.play(move)
	if record == null:
		push_error("The Bot chose an illegal Move")
		return
	_selected = BoardViewState.NO_SQUARE
	_show_move(record)
	if _session.phase() == MatchSession.Phase.PLAYING and not _session.is_bot_turn():
		_screen.play_turn_banner()
	_start_bot_turn_if_due()


func use_preferences(preferences: PlayerPreferences) -> void:
	_preferences = preferences
	_screen.use_preferences(preferences)


func use_sound(sound: SoundOutput) -> void:
	_screen.use_sound(sound)


func set_layout(layout: ScreenLayout.Id) -> void:
	_screen.set_layout(layout)


func set_phone(phone: bool) -> void:
	_screen.set_phone(phone)


## Starts the first game. [param create_session] returns a new MatchSession
## each time a game starts; [param opponent_name] names the Bot, and is empty
## when two people share the device.
func start(create_session: Callable, opponent_name: String = "") -> void:
	_create_session = create_session
	_opponent_name = opponent_name
	_start_new_game()


## One slice of the Bot's search. Logs how long the whole turn took, and its
## slowest frame, so speed can be checked in the browser console.
func _step_bot_thinking() -> void:
	var step_started_msec: int = Time.get_ticks_msec()
	_bot_thinking.step()
	var step_msec: int = Time.get_ticks_msec() - step_started_msec
	_bot_thinking_frames += 1
	_bot_busy_msec += step_msec
	_bot_slowest_step_msec = maxi(_bot_slowest_step_msec, step_msec)
	if _bot_thinking.is_done():
		print("Bot turn: %d ms thinking in %d frames (slowest %d ms), %d ms wall clock" % [
			_bot_busy_msec,
			_bot_thinking_frames,
			_bot_slowest_step_msec,
			Time.get_ticks_msec() - _bot_turn_started_msec,
		])


func _start_new_game() -> void:
	var created: Variant = _create_session.call()
	if created is not MatchSession:
		push_error("create_session must return a MatchSession")
		return
	_session = created
	_selected = BoardViewState.NO_SQUARE
	_turn_finished = false
	_last_fight = null
	_bot_thinking = null
	_screen.close_overlays()
	_screen.show_subtitle(_subtitle())
	if _shares_device():
		_viewer = Side.Id.RED
		_refresh()
		_handoff_screen.present(
			Translated.text(&"SETUP_RED_TITLE"),
			Translated.text(&"SETUP_RED_SUMMARY"),
		)
		return
	_handoff_screen.hide()
	_viewer = _person_side()
	_refresh()
	_start_bot_turn_if_due()


## True when two people pass the device between them.
func _shares_device() -> bool:
	return _session.human_sides().size() > 1


## The side of the only person playing, or Red when Bots play each other.
func _person_side() -> Side.Id:
	var sides: Array[Side.Id] = _session.human_sides()
	return sides[0] if not sides.is_empty() else Side.Id.RED


func _start_bot_turn_if_due() -> void:
	if not _session.is_bot_turn():
		return
	_bot_thinking = _session.start_bot_thinking()
	_bot_turn_elapsed = 0.0
	_bot_turn_started_msec = Time.get_ticks_msec()
	_bot_slowest_step_msec = 0
	_bot_busy_msec = 0
	_bot_thinking_frames = 0
	_refresh()


func _on_quit_requested() -> void:
	_bot_thinking = null
	_screen.close_overlays()
	menu_requested.emit()


func _on_handoff_continued() -> void:
	_viewer = _session.active_side()
	_refresh()
	if _session.phase() == MatchSession.Phase.PLAYING:
		_screen.play_turn_banner()


func _on_square_pressed(square: Vector2i) -> void:
	match _session.phase():
		MatchSession.Phase.SETUP:
			_press_during_setup(square)
		MatchSession.Phase.PLAYING:
			if not _turn_finished and not _session.is_bot_turn():
				_press_during_play(square)


func _on_board_cancelled() -> void:
	_selected = BoardViewState.NO_SQUARE
	_refresh()


func _press_during_setup(square: Vector2i) -> void:
	if not _session.active_setup().is_setup_square(square):
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
	_session.swap_in_active_setup(first, square)
	_refresh()
	_screen.play_swap(first, square)


func _press_during_play(square: Vector2i) -> void:
	var game: Game = _session.game()
	var piece: Piece = game.board().piece_at(square)
	var is_own_piece: bool = piece != null and piece.side == game.side_to_move()
	if is_own_piece and square != _selected:
		_selected = square
	elif _selected != BoardViewState.NO_SQUARE and square in game.legal_destinations(_selected):
		var record: MoveRecord = _session.play(Move.new(_selected, square))
		_selected = BoardViewState.NO_SQUARE
		var still_playing: bool = _session.phase() == MatchSession.Phase.PLAYING
		_turn_finished = still_playing and _shares_device()
		_show_move(record)
		_start_bot_turn_if_due()
		return
	else:
		_selected = BoardViewState.NO_SQUARE
	_refresh()


func _show_move(record: MoveRecord) -> void:
	if record != null and record.fight != null:
		_last_fight = PublicMoveEvent.of(record)
	_refresh()
	if record != null:
		_screen.play_move(PublicMoveEvent.of(record))


func _on_shuffle_pressed() -> void:
	var before: Board = _board_state().board
	_session.shuffle_active_setup()
	_selected = BoardViewState.NO_SQUARE
	_refresh()
	_screen.play_shuffle(before)


func _on_action_pressed() -> void:
	match _session.phase():
		MatchSession.Phase.SETUP:
			_confirm_setup()
		MatchSession.Phase.PLAYING:
			_hand_over_turn()


func _confirm_setup() -> void:
	_session.confirm_setup()
	_selected = BoardViewState.NO_SQUARE
	if not _shares_device():
		_refresh()
		if not _session.is_bot_turn():
			_screen.play_turn_banner()
		_start_bot_turn_if_due()
	elif _session.phase() == MatchSession.Phase.SETUP:
		_handoff_screen.present(
			_pass_device_text(Side.Id.GREEN),
			Translated.text(&"SETUP_GREEN_SUMMARY"),
		)
	else:
		_handoff_screen.present(
			_pass_device_text(Side.Id.RED),
			Translated.text(&"SETUP_DONE_SUMMARY"),
		)


func _hand_over_turn() -> void:
	_turn_finished = false
	_handoff_screen.present(
		_pass_device_text(_session.active_side()),
		MatchNarrator.describe_move(_session.last_record()),
	)


func _pass_device_text(next_player: Side.Id) -> String:
	return Translated.text(&"HANDOFF_PASS_TO", {"side": PieceNames.side_name(next_player)})


func _refresh() -> void:
	if _session == null:
		return
	var phase: MatchSession.Phase = _session.phase()
	_screen.set_phase(_screen_phase(phase))
	_screen.show_board(_board_state())
	_show_players()
	_show_status()
	_show_beside_board()
	match phase:
		MatchSession.Phase.SETUP:
			_screen.show_board_actions(true, Translated.text(&"MATCH_READY"), true)
		MatchSession.Phase.PLAYING:
			var action: String = Translated.text(&"MATCH_PASS_DEVICE") if _turn_finished else ""
			_screen.show_board_actions(false, action, true)
		_:
			_screen.show_board_actions(false, "", false)
			if not _screen.is_result_shown():
				_screen.show_result(_result_view())


func _screen_phase(phase: MatchSession.Phase) -> MatchScreen.Phase:
	match phase:
		MatchSession.Phase.SETUP:
			return MatchScreen.Phase.SETUP
		MatchSession.Phase.PLAYING:
			return MatchScreen.Phase.PLAY
		_:
			return MatchScreen.Phase.OVER


func _show_players() -> void:
	var opponent: Side.Id = Side.opponent(_viewer)
	_screen.show_player(MatchScreen.Slot.YOU, _name_of(_viewer), _viewer, true)
	_screen.show_player(MatchScreen.Slot.OPPONENT, _name_of(opponent), opponent, false)
	_screen.show_graveyard(MatchScreen.Slot.YOU, _session.graveyard(_viewer))
	_screen.show_graveyard(MatchScreen.Slot.OPPONENT, _session.graveyard(opponent))
	var opponent_status: String = ""
	if _session.phase() == MatchSession.Phase.SETUP and _session.is_bot(opponent):
		opponent_status = Translated.text(&"PLAYER_READY")
	_screen.show_player_status(MatchScreen.Slot.OPPONENT, opponent_status)
	_screen.show_player_status(MatchScreen.Slot.YOU, "")
	var active: MatchScreen.Slot = MatchScreen.Slot.NONE
	if _session.phase() == MatchSession.Phase.PLAYING and not _turn_finished:
		active = MatchScreen.Slot.YOU if _session.active_side() == _viewer else MatchScreen.Slot.OPPONENT
	_screen.show_turn(active, -1.0)


func _show_status() -> void:
	match _session.phase():
		MatchSession.Phase.SETUP:
			if _shares_device():
				_screen.show_status(Translated.text(&"STATUS_SETUP", {"side": _name_of(_viewer)}))
			else:
				_screen.show_status(Translated.text(&"ONLINE_ARRANGE"))
		MatchSession.Phase.PLAYING:
			if _session.is_bot_turn():
				_screen.show_status(
					Translated.text(&"STATUS_THINKING", {"side": _name_of(_session.active_side())}),
					UiTokens.GREEN_400, true
				)
			elif _turn_finished:
				_screen.show_status(Translated.text(&"STATUS_TURN_OVER"))
			elif _shares_device():
				_screen.show_status(
					Translated.text(&"STATUS_TO_MOVE", {"side": _name_of(_session.active_side())}),
					UiTokens.GOLD_500
				)
			else:
				_screen.show_status(Translated.text(&"ONLINE_YOUR_TURN"), UiTokens.GOLD_500)
		_:
			_screen.show_finished(Translated.text(&"RESULT_GAME_OVER"))
	_screen.hide_timer()


func _show_beside_board() -> void:
	if _session.phase() == MatchSession.Phase.SETUP:
		var piece: Piece = _session.display_board().piece_at(_selected)
		if piece != null:
			_screen.show_selected_piece(piece.type, piece.side, _selected)
		else:
			_screen.show_no_selected_piece()
		return
	if _last_fight != null:
		_screen.show_last_fight(_last_fight)
	else:
		_screen.show_no_fight()


func _board_state() -> BoardViewState:
	var state: BoardViewState = BoardViewState.new()
	state.viewer = _viewer
	state.selected = _selected
	var record: MoveRecord = _session.last_record()
	state.last_move = record.move if record != null else null
	if _session.phase() == MatchSession.Phase.SETUP:
		state.board = _own_pieces(_session.display_board())
		state.cover_enemy_zone = true
		state.enemy_zone_label = Translated.text(&"ZONE_HIDDEN", {"name": _name_of(Side.opponent(_viewer))})
		return state
	state.board = _session.display_board()
	state.reveal_all = _session.phase() == MatchSession.Phase.OVER
	if _session.phase() == MatchSession.Phase.PLAYING and _selected != BoardViewState.NO_SQUARE:
		state.destinations = _session.game().legal_destinations(_selected)
	return state


## [param board] with only the viewer's Pieces, so a Setup never shows the
## enemy Army, even hidden.
func _own_pieces(board: Board) -> Board:
	var own: Board = Board.new()
	for square: Vector2i in board.squares_of(_viewer):
		own.place(board.piece_at(square), square)
	return own


func _result_view() -> MatchResultView:
	var names: Dictionary[Side.Id, String] = {
		Side.Id.RED: _name_of(Side.Id.RED),
		Side.Id.GREEN: _name_of(Side.Id.GREEN),
	}
	var view: MatchResultView = MatchResultView.of(
		_session.game().result(), _viewer, _shares_device(), _last_fight,
		_session.graveyard(Side.Id.RED), _session.graveyard(Side.Id.GREEN), names
	)
	view.primary_label = Translated.text(&"MATCH_NEW_GAME")
	view.secondary_label = Translated.text(&"MATCH_MENU")
	return view


## A side's name: its colour on a shared device, else the person's nickname
## (or "You") and the Bot's name.
func _name_of(side: Side.Id) -> String:
	if _shares_device():
		return PieceNames.side_name(side)
	if _session.is_bot(side):
		return _opponent_name
	var nickname: String = _preferences.nickname if _preferences != null else ""
	return nickname if not nickname.is_empty() else Translated.text(&"CHAT_YOU")


func _subtitle() -> String:
	if _shares_device():
		return Translated.text(&"MENU_TWO_PLAYERS")
	return Translated.text(&"SUBTITLE_AGAINST", {"opponent": _opponent_name})
