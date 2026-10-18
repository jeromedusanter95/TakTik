class_name KnownPosition
extends RefCounted
## A game as one online player knows it: their own Pieces with their Piece
## Types, enemy Pieces only by Square, whose turn it is and how it stands.
## Enough to find legal Moves and draw the Board, and never an enemy Piece
## Type: enemy Pieces carry a stand-in Type, drawn as Hidden Pieces.

## The Type every enemy Piece carries here. Where a Piece may move never
## depends on the Type of an enemy in its way, so legal Moves stay right.
const HIDDEN_TYPE_STAND_IN: PieceType.Id = PieceType.Id.KING

var viewer: Side.Id:
	get:
		return _viewer
var result: GameResult:
	get:
		return _result

var _viewer: Side.Id
var _game: Game
var _result: GameResult


## [param game] holds the viewer's real Pieces and, for each enemy Piece, one
## of Type [constant HIDDEN_TYPE_STAND_IN].
func _init(seen_by: Side.Id, game: Game, game_result: GameResult) -> void:
	_viewer = seen_by
	_game = game
	_result = game_result


func side_to_move() -> Side.Id:
	return _game.side_to_move()


func is_viewers_turn() -> bool:
	return not _result.is_over() and _game.side_to_move() == _viewer


## The Board to draw, with enemy Pieces only fit to be shown hidden.
func board() -> Board:
	return _game.board()


func is_own_piece(square: Vector2i) -> bool:
	var piece: Piece = _game.board().piece_at(square)
	return piece != null and piece.side == _viewer


func legal_destinations(from: Vector2i) -> Array[Vector2i]:
	if not is_viewers_turn():
		return []
	return _game.legal_destinations(from)


func view() -> PlayerView:
	return PlayerView.of(_game, _viewer)
