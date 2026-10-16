class_name BotThinking
extends RefCounted
## One Bot turn being computed, spread over several frames so the screen stays
## responsive.
##
## PLACEHOLDER: picks a random legal Move. To be replaced by the
## sampling search of ADR 0002.

var _view: PlayerView
var _rng: RandomNumberGenerator
var _chosen: Move = null


func _init(view: PlayerView, rng: RandomNumberGenerator) -> void:
	_view = view
	_rng = rng


## Does one slice of work. Call once per frame until [method is_done].
func step() -> void:
	if is_done():
		return
	var moves: Array[Move] = _own_legal_moves()
	_chosen = moves[_rng.randi_range(0, moves.size() - 1)]


func is_done() -> bool:
	return _chosen != null


## The Move to play. Only valid once [method is_done] is true.
func chosen_move() -> Move:
	return _chosen


## The Bot's legal Moves never depend on enemy Piece Types, so any stand-in
## type gives the right list.
func _own_legal_moves() -> Array[Move]:
	var board: Board = Board.new()
	var next_id: int = 0
	for square: Vector2i in _view.own_squares():
		board.place(Piece.new(next_id, _view.own_type_at(square), _view.side), square)
		next_id += 1
	for square: Vector2i in _view.enemy_squares():
		board.place(Piece.new(next_id, PieceType.Id.SOLDIER, Side.opponent(_view.side)), square)
		next_id += 1
	var game: Game = Game.new(board, _view.side_to_move, _view.plies_without_fight, _view.last_moves())
	return game.legal_moves()
