class_name LocalMatch
extends Control
## Two players taking turns on one device. Shows the Board only to the player
## holding the device and covers it while the device changes hands.

var _create_session: Callable = Callable()
var _session: MatchSession = null
## The player currently looking at the screen. Stays the mover after a Move
## until the device is handed over.
var _viewer: Side.Id = Side.Id.RED
var _selected: Vector2i = BoardViewState.NO_SQUARE
var _turn_finished: bool = false

@onready var _status_label: Label = %StatusLabel
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


## Starts the first game. [param create_session] returns a new
## MatchSession each time a game starts.
func start(create_session: Callable) -> void:
	_create_session = create_session
	_start_new_game()


func _start_new_game() -> void:
	_session = _create_session.call()
	_selected = BoardViewState.NO_SQUARE
	_turn_finished = false
	_handoff_screen.present(
		"Red, set up your Army",
		"Green must not look. Tap two of your Pieces to swap them, or Shuffle.",
	)


func _on_handoff_continued() -> void:
	_viewer = _session.active_side()
	_refresh()


func _on_square_pressed(square: Vector2i) -> void:
	match _session.phase():
		MatchSession.Phase.SETUP:
			_press_during_setup(square)
		MatchSession.Phase.PLAYING:
			if not _turn_finished:
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
		_turn_finished = _session.phase() == MatchSession.Phase.PLAYING
	else:
		_selected = BoardViewState.NO_SQUARE
	_refresh()


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
	if _session.phase() == MatchSession.Phase.SETUP:
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
			return "Your turn is over" if _turn_finished else "%s to move" % viewer
		_:
			return MatchNarrator.describe_result(_session.game().result())


func _info_text() -> String:
	var record: MoveRecord = _session.last_record()
	if _session.phase() != MatchSession.Phase.SETUP and record != null and record.fight != null:
		if _turn_finished or _session.phase() == MatchSession.Phase.OVER:
			return MatchNarrator.describe_fight(record.fight)
	if _selected == BoardViewState.NO_SQUARE:
		return "Tap one of your Pieces." if _session.phase() != MatchSession.Phase.OVER else ""
	var piece: Piece = _session.display_board().piece_at(_selected)
	return MatchNarrator.describe_piece(piece.type) if piece != null else ""


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
