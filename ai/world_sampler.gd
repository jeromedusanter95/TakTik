class_name WorldSampler
extends RefCounted
## Imagines one full Game consistent with everything a Bot knows: its own
## Pieces as they are and the enemy Pieces with the types its
## HiddenTypeChooser gives them.

var _tracker: EnemyTracker
var _rng: RandomNumberGenerator
var _chooser: HiddenTypeChooser


func _init(
		tracker: EnemyTracker,
		rng: RandomNumberGenerator,
		chooser: HiddenTypeChooser = ShuffledTypeChooser.new(),
) -> void:
	_tracker = tracker
	_rng = rng
	_chooser = chooser


func sample(view: PlayerView) -> Game:
	var board: Board = Board.new()
	var next_id: int = 0
	for square: Vector2i in view.own_squares():
		board.place(Piece.new(next_id, view.own_type_at(square), view.side), square)
		next_id += 1
	var enemy_types: Dictionary[Vector2i, PieceType.Id] = _chooser.choose(view, _tracker, _rng)
	var enemy_side: Side.Id = Side.opponent(view.side)
	for square: Vector2i in view.enemy_squares():
		board.place(Piece.new(next_id, enemy_types[square], enemy_side), square)
		next_id += 1
	return Game.new(board, view.side_to_move, view.plies_without_fight, view.last_moves())
