class_name WeightedTypeChooser
extends HiddenTypeChooser
## Draws each unknown enemy Piece's type in turn, in a random order, with a
## chance proportional to how many of that type are left times how well the
## type fits the Piece's behaviour (TrackedEnemy.likelihood). A draw is
## refused when it would leave a later Piece with no type it may have.


func choose(
		view: PlayerView,
		tracker: EnemyTracker,
		rng: RandomNumberGenerator,
) -> Dictionary[Vector2i, PieceType.Id]:
	var types: Dictionary[Vector2i, PieceType.Id] = {}
	var unknown: Array[Vector2i] = []
	for square: Vector2i in view.enemy_squares():
		var enemy: TrackedEnemy = tracker.enemy_at(square)
		if enemy.is_known():
			types[square] = enemy.known_type()
		else:
			unknown.append(square)
	var pool: UnknownPool = UnknownPool.new(tracker.unknown_pool(), tracker, unknown)
	_shuffle(unknown, rng)
	for square: Vector2i in unknown:
		types[square] = pool.draw(tracker.enemy_at(square), rng)
	return types


static func _shuffle(squares: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for index: int in range(squares.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var kept: Vector2i = squares[index]
		squares[index] = squares[other]
		squares[other] = kept


## The types still to hand out, and how many moved Pieces still wait for
## one, so no draw makes the rest impossible.
class UnknownPool:
	extends RefCounted

	var _counts: Dictionary[PieceType.Id, int] = {}
	var _moved_left: int = 0

	func _init(
			types: Array[PieceType.Id],
			tracker: EnemyTracker,
			squares: Array[Vector2i],
	) -> void:
		for type: PieceType.Id in types:
			_counts[type] = _counts.get(type, 0) + 1
		for square: Vector2i in squares:
			if tracker.enemy_at(square).has_moved():
				_moved_left += 1

	## The fallback only matters if the memory contradicts the Army.
	func draw(enemy: TrackedEnemy, rng: RandomNumberGenerator) -> PieceType.Id:
		var moved: bool = enemy.has_moved()
		var candidates: Array[PieceType.Id] = []
		var weights: PackedFloat32Array = PackedFloat32Array()
		for type: PieceType.Id in _counts:
			if _counts[type] > 0 and _allows(type, moved):
				candidates.append(type)
				weights.append(_counts[type] * maxf(enemy.likelihood(type), 0.0001))
		if candidates.is_empty():
			return PieceType.Id.SOLDIER
		var chosen: PieceType.Id = candidates[rng.rand_weighted(weights)]
		_take(chosen, moved)
		return chosen

	## An unmoved Piece taking a mobile type must leave enough mobile types
	## for the moved Pieces still waiting.
	func _allows(type: PieceType.Id, moved: bool) -> bool:
		if type == PieceType.Id.MONSTER:
			return not moved
		if moved:
			return true
		return _mobile_left() - 1 >= _moved_left

	func _take(type: PieceType.Id, moved: bool) -> void:
		_counts[type] -= 1
		if moved:
			_moved_left -= 1

	func _mobile_left() -> int:
		var total: int = 0
		for type: PieceType.Id in _counts:
			if type != PieceType.Id.MONSTER:
				total += _counts[type]
		return total
