class_name WorldSampler
extends RefCounted
## Imagines one full Game consistent with everything a Bot knows: its own
## Pieces as they are, the enemy Pieces whose type it remembers, and the
## remaining Piece Types shuffled onto the other enemy Pieces, never giving a
## Monster to a Piece that has moved.

var _tracker: EnemyTracker
var _rng: RandomNumberGenerator


func _init(tracker: EnemyTracker, rng: RandomNumberGenerator) -> void:
	_tracker = tracker
	_rng = rng


func sample(view: PlayerView) -> Game:
	var board: Board = Board.new()
	var next_id: int = 0
	for square: Vector2i in view.own_squares():
		board.place(Piece.new(next_id, view.own_type_at(square), view.side), square)
		next_id += 1
	var enemy_types: Dictionary[Vector2i, PieceType.Id] = _imagine_enemy_types(view)
	var enemy_side: Side.Id = Side.opponent(view.side)
	for square: Vector2i in view.enemy_squares():
		board.place(Piece.new(next_id, enemy_types[square], enemy_side), square)
		next_id += 1
	return Game.new(board, view.side_to_move, view.plies_without_fight, view.last_moves())


func _imagine_enemy_types(view: PlayerView) -> Dictionary[Vector2i, PieceType.Id]:
	var types: Dictionary[Vector2i, PieceType.Id] = {}
	var moved: Array[Vector2i] = []
	var unmoved: Array[Vector2i] = []
	for square: Vector2i in view.enemy_squares():
		var enemy: TrackedEnemy = _tracker.enemy_at(square)
		if enemy.is_known():
			types[square] = enemy.known_type()
		elif enemy.has_moved():
			moved.append(square)
		else:
			unmoved.append(square)
	var pool: Array[PieceType.Id] = _shuffled(_tracker.unknown_pool())
	for square: Vector2i in moved:
		types[square] = _take_mobile_type(pool)
	for square: Vector2i in unmoved:
		types[square] = _take_any_type(pool)
	return types


func _shuffled(pool: Array[PieceType.Id]) -> Array[PieceType.Id]:
	for index: int in range(pool.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var kept: PieceType.Id = pool[index]
		pool[index] = pool[other]
		pool[other] = kept
	return pool


## Takes the first type in [param pool] that can move. The fallback only
## matters if the memory contradicts the Army, which observing every event
## from the start prevents.
static func _take_mobile_type(pool: Array[PieceType.Id]) -> PieceType.Id:
	for index: int in pool.size():
		if pool[index] != PieceType.Id.MONSTER:
			var type: PieceType.Id = pool[index]
			pool.remove_at(index)
			return type
	return PieceType.Id.SOLDIER


static func _take_any_type(pool: Array[PieceType.Id]) -> PieceType.Id:
	if pool.is_empty():
		return PieceType.Id.SOLDIER
	var type: PieceType.Id = pool[0]
	pool.remove_at(0)
	return type
