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
## The player currently looking at the screen. With two people it stays the
## mover after a Move until the device is handed over.
var _viewer: Side.Id = Side.Id.RED
var _selected: Vector2i = BoardViewState.NO_SQUARE
var _turn_finished: bool = false
var _bot_thinking: BotThinking = null
var _bot_turn_elapsed: float = 0.0
var _bot_turn_started_msec: int = 0
var _bot_slowest_step_msec: int = 0
var _bot_thinking_frames: int = 0

@onready var _status_label: Label = %StatusLabel
@onready var _menu_button: Button = %MenuButton
@onready var _board_view: BoardView = %BoardView
@onready var _info_label: Label = %InfoLabel
@onready var _graveyard_label: Label = %GraveyardLabel
@onready var _shuffle_button: Button = %ShuffleButton
@onready var _action_button: Button = %ActionButton
@onready var _handoff_screen: HandoffScreen = %HandoffScreen


func _ready() -> void:
	_board_view.square_pressed.connect(_on_square_pressed)
	_shuffle_button.pressed.connect(_on_shuffle_pressed)
	_action_button.pressed.connect(_on_action_pressed)
	_handoff_screen.continued.connect(_on_handoff_continued)
	_menu_button.pressed.connect(_on_menu_pressed)


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
	if _session.play(move) == null:
		push_error("The Bot chose an illegal Move")
		return
	_selected = BoardViewState.NO_SQUARE
	_refresh()
	_start_bot_turn_if_due()


## One slice of the Bot's search. Logs how long the whole turn took, and its
## slowest frame, so speed can be checked in the browser console.
func _step_bot_thinking() -> void:
	var step_started_msec: int = Time.get_ticks_msec()
	_bot_thinking.step()
	_bot_thinking_frames += 1
	_bot_slowest_step_msec = maxi(_bot_slowest_step_msec, Time.get_ticks_msec() - step_started_msec)
	if _bot_thinking.is_done():
		print("Bot turn: %d ms computing over %d frames, slowest frame %d ms" % [
			Time.get_ticks_msec() - _bot_turn_started_msec,
			_bot_thinking_frames,
			_bot_slowest_step_msec,
		])


## Starts the first game. [param create_session] returns a new MatchSession
## each time a game starts.
func start(create_session: Callable) -> void:
	_create_session = create_session
	_start_new_game()


func _start_new_game() -> void:
	_session = _create_session.call()
	_selected = BoardViewState.NO_SQUARE
	_turn_finished = false
	_bot_thinking = null
	if _shares_device():
		_handoff_screen.present(
			"Red, set up your Army",
			"Green must not look. Tap two of your Pieces to swap them, or Shuffle.",
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
	_bot_thinking_frames = 0
	_refresh()


func _on_menu_pressed() -> void:
	_bot_thinking = null
	menu_requested.emit()


func _on_handoff_continued() -> void:
	_viewer = _session.active_side()
	_refresh()


func _on_square_pressed(square: Vector2i) -> void:
	match _session.phase():
		MatchSession.Phase.SETUP:
			_press_during_setup(square)
		MatchSession.Phase.PLAYING:
			if not _turn_finished and not _session.is_bot_turn():
				_press_during_play(square)


func _press_during_setup(square: Vector2i) -> void:
	if not _session.active_setup().is_setup_square(square):
		return
	if _selected == BoardViewState.NO_SQUARE:
		_selected = square
	else:
		_session.swap_in_active_setup(_selected, square)
		_selected = BoardViewState.NO_SQUARE
	_refresh()


func _press_during_play(square: Vector2i) -> void:
	var game: Game = _session.game()
	var piece: Piece = game.board().piece_at(square)
	var is_own_piece: bool = piece != null and piece.side == game.side_to_move()
	if is_own_piece and square != _selected:
		_selected = square
	elif _selected != BoardViewState.NO_SQUARE and square in game.legal_destinations(_selected):
		_session.play(Move.new(_selected, square))
		_selected = BoardViewState.NO_SQUARE
		var still_playing: bool = _session.phase() == MatchSession.Phase.PLAYING
		_turn_finished = still_playing and _shares_device()
	else:
		_selected = BoardViewState.NO_SQUARE
	_refresh()
	_start_bot_turn_if_due()


func _on_shuffle_pressed() -> void:
	_session.shuffle_active_setup()
	_selected = BoardViewState.NO_SQUARE
	_refresh()


func _on_action_pressed() -> void:
	match _session.phase():
		MatchSession.Phase.SETUP:
			_confirm_setup()
		MatchSession.Phase.PLAYING:
			_hand_over_turn()
		MatchSession.Phase.OVER:
			_start_new_game()


func _confirm_setup() -> void:
	_session.confirm_setup()
	_selected = BoardViewState.NO_SQUARE
	if not _shares_device():
		_refresh()
		_start_bot_turn_if_due()
	elif _session.phase() == MatchSession.Phase.SETUP:
		_handoff_screen.present(
			"Pass the device to Green",
			"Green, set up your Army. Red must not look.",
		)
	else:
		_handoff_screen.present("Pass the device to Red", "Both Armies are ready. Red moves first.")


func _hand_over_turn() -> void:
	_turn_finished = false
	var next_player: String = PieceNames.side_name(_session.active_side())
	_handoff_screen.present(
		"Pass the device to %s" % next_player,
		MatchNarrator.describe_move(_session.last_record()),
	)


func _refresh() -> void:
	_board_view.show_state(_board_state())
	_status_label.text = _status_text()
	_info_label.text = _info_text()
	_graveyard_label.text = _graveyard_text()
	var phase: MatchSession.Phase = _session.phase()
	_shuffle_button.visible = phase == MatchSession.Phase.SETUP
	_action_button.visible = phase != MatchSession.Phase.PLAYING or _turn_finished
	_action_button.text = _action_text()


func _board_state() -> BoardViewState:
	var state: BoardViewState = BoardViewState.new()
	state.board = _session.display_board()
	state.viewer = _viewer
	state.reveal_all = _session.phase() == MatchSession.Phase.OVER
	state.selected = _selected
	var record: MoveRecord = _session.last_record()
	state.last_move = record.move if record != null else null
	if _session.phase() == MatchSession.Phase.PLAYING and _selected != BoardViewState.NO_SQUARE:
		state.destinations = _session.game().legal_destinations(_selected)
	return state


func _status_text() -> String:
	var viewer: String = PieceNames.side_name(_viewer)
	match _session.phase():
		MatchSession.Phase.SETUP:
			return "%s: arrange your Army" % viewer
		MatchSession.Phase.PLAYING:
			if _session.is_bot_turn():
				return "%s is thinking..." % PieceNames.side_name(_session.active_side())
			if _turn_finished:
				return "Your turn is over"
			return "%s to move" % PieceNames.side_name(_session.active_side())
		_:
			return MatchNarrator.describe_result(_session.game().result())


func _info_text() -> String:
	var phase: MatchSession.Phase = _session.phase()
	if phase == MatchSession.Phase.SETUP or _selected != BoardViewState.NO_SQUARE:
		return _selected_piece_text()
	if not _shares_device():
		return _round_text()
	var record: MoveRecord = _session.last_record()
	if record != null and record.fight != null:
		if _turn_finished or phase == MatchSession.Phase.OVER:
			return MatchNarrator.describe_fight(record.fight)
	return "Tap one of your Pieces." if phase != MatchSession.Phase.OVER else ""


func _selected_piece_text() -> String:
	if _selected == BoardViewState.NO_SQUARE:
		return "Tap one of your Pieces."
	var piece: Piece = _session.display_board().piece_at(_selected)
	return MatchNarrator.describe_piece(piece.type) if piece != null else ""


## Against a Bot: the Fight the person's last Move caused, if any, then what
## the Bot answered.
func _round_text() -> String:
	var lines: PackedStringArray = []
	var own: MoveRecord = _session.last_record_of(_viewer)
	if own != null and own.fight != null:
		lines.append(MatchNarrator.describe_fight(own.fight))
	var last: MoveRecord = _session.last_record()
	if last != null and last != own:
		lines.append(MatchNarrator.describe_move(last))
	var persons_turn: bool = (
		_session.phase() == MatchSession.Phase.PLAYING and not _session.is_bot_turn()
	)
	if lines.is_empty() and persons_turn:
		lines.append("Tap one of your Pieces.")
	return "\n".join(lines)


func _graveyard_text() -> String:
	if _session.phase() == MatchSession.Phase.SETUP:
		return ""
	return "%s\n%s" % [
		MatchNarrator.describe_graveyard(Side.Id.RED, _session.graveyard(Side.Id.RED)),
		MatchNarrator.describe_graveyard(Side.Id.GREEN, _session.graveyard(Side.Id.GREEN)),
	]


func _action_text() -> String:
	match _session.phase():
		MatchSession.Phase.SETUP:
			return "Ready"
		MatchSession.Phase.PLAYING:
			return "Pass the device"
		_:
			return "New game"
