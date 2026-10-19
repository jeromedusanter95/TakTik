extends GutTest


func test_it_places_the_requested_guards_without_changing_the_army() -> void:
	for side: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
		for requested: int in [-1, 0, 1, 2, 3, 9]:
			var plan: VariedPrincessSetupPlan = VariedPrincessSetupPlan.new()
			plan.monster_guards = requested
			for seed_value: int in 20:
				var rng: RandomNumberGenerator = RandomNumberGenerator.new()
				rng.seed = seed_value
				var setup: Setup = plan.arrange(side, rng)
				assert_true(setup.is_valid())
				_assert_guards(setup, requested)


func _assert_guards(setup: Setup, requested: int) -> void:
	for square: Vector2i in setup.squares():
		if setup.type_at(square) != PieceType.Id.PRINCESS:
			continue
		assert_eq(square.y, Board.home_row(setup.side))
		var neighbours: Array = Board.steps_from(square)
		var count: int = 0
		for neighbour: Vector2i in neighbours:
			if setup.type_at(neighbour) == PieceType.Id.MONSTER:
				count += 1
		assert_eq(count, clampi(requested, 0, neighbours.size()))
