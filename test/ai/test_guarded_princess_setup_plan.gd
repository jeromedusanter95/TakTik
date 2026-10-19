extends GutTest
## The Setup a careful Bot arranges.


func test_it_arranges_a_whole_army() -> void:
	for side: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
		for seed_value: int in 20:
			assert_true(_arrange(side, seed_value).is_valid(), "seed %d" % seed_value)


func test_the_princess_hides_on_the_home_row_behind_monsters() -> void:
	for side: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
		for seed_value: int in 20:
			var setup: Setup = _arrange(side, seed_value)
			var princess: Vector2i = _square_of(setup, PieceType.Id.PRINCESS)
			assert_eq(princess.y, Board.home_row(side))
			for neighbour: Vector2i in Board.steps_from(princess):
				assert_eq(setup.type_at(neighbour), PieceType.Id.MONSTER, "seed %d" % seed_value)


func test_the_princess_is_not_always_on_the_same_square() -> void:
	var squares: Array[Vector2i] = []
	for seed_value: int in 20:
		var square: Vector2i = _square_of(_arrange(Side.Id.RED, seed_value), PieceType.Id.PRINCESS)
		if not squares.has(square):
			squares.append(square)
	assert_gt(squares.size(), 3)


func _arrange(side: Side.Id, seed_value: int) -> Setup:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return GuardedPrincessSetupPlan.new().arrange(side, rng)


func _square_of(setup: Setup, type: PieceType.Id) -> Vector2i:
	for square: Vector2i in setup.squares():
		if setup.type_at(square) == type:
			return square
	return Vector2i(-1, -1)
