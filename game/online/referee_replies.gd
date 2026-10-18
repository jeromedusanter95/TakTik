class_name RefereeReplies
extends RefCounted
## Reads the messages of an online game's socket into typed replies. Anything
## that does not have the expected shape becomes a MALFORMED reply, never a
## crash.

const _NO_SQUARE: Vector2i = Vector2i(-1, -1)
## What _time_left returns for a time left that is there but not a whole
## number of milliseconds.
const _MALFORMED_TIME_LEFT: int = -2


static func read(text: String) -> RefereeReply:
	var reply: RefereeReply = RefereeReply.new()
	var message: Dictionary = WireJson.parsed_object(text)
	match message.get("type"):
		"seated":
			_read_seated(message, reply)
		"setup_status":
			_read_setup_status(message, reply)
		"game_state":
			_read_game_state(message, reply)
		"moved":
			_read_moved(message, reply)
		"opponent_presence":
			_read_opponent_presence(message, reply)
		"quick_chat":
			_read_quick_chat(message, reply)
		"rematch_offered":
			reply.kind = RefereeReply.Kind.REMATCH_OFFERED
		"rematch_ready":
			reply.rematch_seat = PairedSeatReader.read(message)
			if reply.rematch_seat != null:
				reply.kind = RefereeReply.Kind.REMATCH_READY
		"refused":
			reply.refusal = WireJson.text(message.get("reason"))
			reply.kind = RefereeReply.Kind.REFUSED
	return reply


static func _read_seated(message: Dictionary, reply: RefereeReply) -> void:
	var side_name: Variant = message.get("side")
	if not WireNames.is_side(side_name):
		return
	reply.side = WireNames.side(side_name)
	reply.opponent = WireJson.text(message.get("opponent"))
	reply.kind = RefereeReply.Kind.SEATED


static func _read_setup_status(message: Dictionary, reply: RefereeReply) -> void:
	var own: Variant = message.get("ownSetupDone")
	var opponent: Variant = message.get("opponentSetupDone")
	var time_left: int = _time_left(message, "setupTimeLeftMs")
	if own is not bool or opponent is not bool or time_left == _MALFORMED_TIME_LEFT:
		return
	reply.own_setup_done = own
	reply.opponent_setup_done = opponent
	reply.setup_time_left_msec = time_left
	reply.kind = RefereeReply.Kind.SETUP_STATUS


static func _read_game_state(message: Dictionary, reply: RefereeReply) -> void:
	var history: Variant = message.get("history")
	reply.position = _position(WireJson.object(message.get("view")))
	if reply.position == null or history is not Array:
		return
	var events: Array = history
	for item: Variant in events:
		var event: PublicMoveEvent = _event(WireJson.object(item))
		if event == null:
			return
		reply.history.append(event)
	reply.turn_time_left_msec = _time_left(message, "turnTimeLeftMs")
	if not _read_final_board(message, reply) or reply.turn_time_left_msec == _MALFORMED_TIME_LEFT:
		return
	reply.kind = RefereeReply.Kind.GAME_STATE


static func _read_moved(message: Dictionary, reply: RefereeReply) -> void:
	reply.position = _position(WireJson.object(message.get("view")))
	reply.event = _event(WireJson.object(message.get("event")))
	reply.turn_time_left_msec = _time_left(message, "turnTimeLeftMs")
	if (
		reply.position == null or reply.event == null or not _read_final_board(message, reply)
		or reply.turn_time_left_msec == _MALFORMED_TIME_LEFT
	):
		return
	reply.kind = RefereeReply.Kind.MOVED


static func _read_opponent_presence(message: Dictionary, reply: RefereeReply) -> void:
	var connected: Variant = message.get("connected")
	if connected is not bool:
		return
	reply.opponent_connected = connected
	reply.forfeit_in_msec = _time_left(message, "forfeitInMs")
	reply.kind = RefereeReply.Kind.OPPONENT_PRESENCE


static func _read_quick_chat(message: Dictionary, reply: RefereeReply) -> void:
	var side_name: Variant = message.get("side")
	var chat: String = WireJson.text(message.get("message"))
	if not WireNames.is_side(side_name) or not QuickChat.is_message(chat):
		return
	reply.chat_side = WireNames.side(side_name)
	reply.chat_message = chat
	reply.kind = RefereeReply.Kind.QUICK_CHAT


## The optional time left under [param key], in milliseconds:
## RefereeReply.NO_TIMER when it is not there, _MALFORMED_TIME_LEFT when it is
## not a whole number of zero or more.
static func _time_left(message: Dictionary, key: String) -> int:
	if not message.has(key):
		return RefereeReply.NO_TIMER
	var time_left: int = WireJson.count(message.get(key))
	return time_left if time_left >= 0 else _MALFORMED_TIME_LEFT


## Reads the optional final Board. False when it is there but malformed.
static func _read_final_board(message: Dictionary, reply: RefereeReply) -> bool:
	if not message.has("finalBoard"):
		return true
	var pieces: Variant = message.get("finalBoard")
	if pieces is not Array:
		return false
	var shown: Array = pieces
	var board: Board = Board.new()
	var next_id: int = 0
	for item: Variant in shown:
		var piece: Dictionary = WireJson.object(item)
		var square: Vector2i = _square(piece.get("square"))
		var type_name: Variant = piece.get("type")
		var side_name: Variant = piece.get("side")
		if square == _NO_SQUARE or not WireNames.is_piece_type(type_name) or not WireNames.is_side(side_name):
			return false
		board.place(Piece.new(next_id, WireNames.piece_type(type_name), WireNames.side(side_name)), square)
		next_id += 1
	reply.final_board = board
	return true


## The game a PlayerView describes, or null when it is malformed.
static func _position(view: Dictionary) -> KnownPosition:
	var side_name: Variant = view.get("side")
	var mover_name: Variant = view.get("sideToMove")
	var plies: int = WireJson.count(view.get("pliesWithoutFight"))
	var result: GameResult = _result(WireJson.object(view.get("result")))
	var board: Board = _known_board(view)
	var last_moves: Dictionary = WireJson.object(view.get("lastMoves"))
	if (
		not WireNames.is_side(side_name) or not WireNames.is_side(mover_name)
		or plies < 0 or result == null or board == null or not _are_last_moves(last_moves)
	):
		return null
	var mover: Side.Id = WireNames.side(mover_name)
	var game: Game = Game.new(board, mover, plies, _last_moves(last_moves))
	return KnownPosition.new(WireNames.side(side_name), game, result)


## The viewer's Pieces with their Types and enemy Pieces with the stand-in
## Type, or null when malformed.
static func _known_board(view: Dictionary) -> Board:
	var side_name: Variant = view.get("side")
	var own: Variant = view.get("ownPieces")
	var enemy: Variant = view.get("enemySquares")
	if not WireNames.is_side(side_name) or own is not Array or enemy is not Array:
		return null
	var viewer: Side.Id = WireNames.side(side_name)
	var board: Board = Board.new()
	var own_pieces: Array = own
	var enemy_squares: Array = enemy
	var next_id: int = 0
	for item: Variant in own_pieces:
		var piece: Dictionary = WireJson.object(item)
		var square: Vector2i = _square(piece.get("square"))
		var type_name: Variant = piece.get("type")
		if square == _NO_SQUARE or not WireNames.is_piece_type(type_name):
			return null
		board.place(Piece.new(next_id, WireNames.piece_type(type_name), viewer), square)
		next_id += 1
	for item: Variant in enemy_squares:
		var square: Vector2i = _square(item)
		if square == _NO_SQUARE:
			return null
		var hidden: Piece = Piece.new(next_id, KnownPosition.HIDDEN_TYPE_STAND_IN, Side.opponent(viewer))
		board.place(hidden, square)
		next_id += 1
	return board


static func _are_last_moves(moves: Dictionary) -> bool:
	for side_name: Variant in moves:
		if not WireNames.is_side(side_name) or _move(moves[side_name]) == null:
			return false
	return true


## Each side's last Move; [param moves] must pass [method _are_last_moves].
static func _last_moves(moves: Dictionary) -> Dictionary[Side.Id, Move]:
	var last_moves: Dictionary[Side.Id, Move] = {}
	for side_name: Variant in moves:
		last_moves[WireNames.side(side_name)] = _move(moves[side_name])
	return last_moves


static func _result(result: Dictionary) -> GameResult:
	var status_name: Variant = result.get("status")
	var reason_name: Variant = result.get("reason")
	if not WireNames.is_status(status_name) or not WireNames.is_reason(reason_name):
		return null
	return GameResult.new(WireNames.status(status_name), WireNames.reason(reason_name))


static func _event(event: Dictionary) -> PublicMoveEvent:
	var side_name: Variant = event.get("moverSide")
	var move: Move = _move(event.get("move"))
	if not WireNames.is_side(side_name) or move == null:
		return null
	var public_event: PublicMoveEvent = PublicMoveEvent.of_move(WireNames.side(side_name), move)
	if not event.has("fight"):
		return public_event
	var fight: Dictionary = WireJson.object(event.get("fight"))
	var attacker: Variant = fight.get("attackerType")
	var defender: Variant = fight.get("defenderType")
	var outcome: Variant = fight.get("outcome")
	if (
		not WireNames.is_piece_type(attacker) or not WireNames.is_piece_type(defender)
		or not WireNames.is_outcome(outcome)
	):
		return null
	return public_event.with_fight(
		WireNames.piece_type(attacker), WireNames.piece_type(defender), WireNames.outcome(outcome)
	)


static func _move(value: Variant) -> Move:
	var move: Dictionary = WireJson.object(value)
	var from: Vector2i = _square(move.get("from"))
	var to: Vector2i = _square(move.get("to"))
	if from == _NO_SQUARE or to == _NO_SQUARE:
		return null
	return Move.new(from, to)


## The Square a { column, row } object names, or _NO_SQUARE.
static func _square(value: Variant) -> Vector2i:
	var square: Dictionary = WireJson.object(value)
	var column: int = WireJson.count(square.get("column"))
	var row: int = WireJson.count(square.get("row"))
	var parsed: Vector2i = Vector2i(column, row)
	return parsed if Board.is_inside(parsed) else _NO_SQUARE
