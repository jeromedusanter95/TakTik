class_name PlayerView
extends RefCounted
## What one player may know about a game at a given moment: their own Pieces,
## the Squares enemy Pieces stand on (never their Piece Types) and the public
## state. Bots and, later, online clients receive only this.

var side: Side.Id:
	get:
		return _side
var side_to_move: Side.Id:
	get:
		return _side_to_move
var plies_without_fight: int:
	get:
		return _plies_without_fight
var is_over: bool:
	get:
		return _is_over

var _side: Side.Id
var _side_to_move: Side.Id
var _plies_without_fight: int
var _is_over: bool
var _own_types: Dictionary[Vector2i, PieceType.Id] = {}
var _enemy_squares: Array[Vector2i] = []
var _last_moves: Dictionary[Side.Id, Move] = {}


static func of(game: Game, viewer: Side.Id) -> PlayerView:
	var view: PlayerView = PlayerView.new()
	view._side = viewer
	view._side_to_move = game.side_to_move()
	view._plies_without_fight = game.plies_without_fight()
	view._is_over = game.result().is_over()
	var board: Board = game.board()
	for square: Vector2i in board.squares_of(viewer):
		view._own_types[square] = board.piece_at(square).type
	view._enemy_squares = board.squares_of(Side.opponent(viewer))
	view._enemy_squares.sort()
	for owner: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
		var last: Move = game.last_move_of(owner)
		if last != null:
			view._last_moves[owner] = last
	return view


func own_squares() -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	for square: Vector2i in _own_types:
		squares.append(square)
	squares.sort()
	return squares


func own_type_at(square: Vector2i) -> PieceType.Id:
	return _own_types[square]


func enemy_squares() -> Array[Vector2i]:
	return _enemy_squares.duplicate()


func last_moves() -> Dictionary[Side.Id, Move]:
	return _last_moves.duplicate()
