class_name ShuffledTypeChooser
extends HiddenTypeChooser
## Shuffles the unknown pool onto the Pieces of unknown type, every
## arrangement the memory allows being about as likely as any other.


func choose(
		view: PlayerView,
		tracker: EnemyTracker,
		rng: RandomNumberGenerator,
) -> Dictionary[Vector2i, PieceType.Id]:
	var types: Dictionary[Vector2i, PieceType.Id] = {}
	var moved: Array[Vector2i] = []
	var unmoved: Array[Vector2i] = []
	for square: Vector2i in view.enemy_squares():
		var enemy: TrackedEnemy = tracker.enemy_at(square)
		if enemy.is_known():
			types[square] = enemy.known_type()
		elif enemy.has_moved():
			moved.append(square)
		else:
			unmoved.append(square)
	var pool: Array[PieceType.Id] = _shuffled(tracker.unknown_pool(), rng)
	for square: Vector2i in moved:
		types[square] = _take_mobile_type(pool)
	for square: Vector2i in unmoved:
		types[square] = _take_any_type(pool)
	return types


static func _shuffled(
		pool: Array[PieceType.Id],
		rng: RandomNumberGenerator,
) -> Array[PieceType.Id]:
	for index: int in range(pool.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
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
