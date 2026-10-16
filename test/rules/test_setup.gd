extends GutTest


func test_random_setup_is_a_valid_army_for_both_sides() -> void:
	for side: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
		var setup: Setup = Setup.random(side, _rng(7))
		assert_true(setup.is_valid(), "random setup for side %d" % side)


func test_random_setup_is_reproducible_with_the_same_seed() -> void:
	var first: Setup = Setup.random(Side.Id.RED, _rng(42))
	var second: Setup = Setup.random(Side.Id.RED, _rng(42))
	for square: Vector2i in Setup.squares_for(Side.Id.RED):
		assert_eq(first.type_at(square), second.type_at(square))


func test_red_sets_up_on_ranks_1_to_3_and_green_on_ranks_6_to_8() -> void:
	assert_eq(Setup.rows_for(Side.Id.RED), [0, 1, 2] as Array[int])
	assert_eq(Setup.rows_for(Side.Id.GREEN), [5, 6, 7] as Array[int])


func test_swap_exchanges_two_pieces_and_keeps_the_army_valid() -> void:
	var setup: Setup = Setup.random(Side.Id.RED, _rng(3))
	var first: Vector2i = Vector2i(0, 0)
	var second: Vector2i = Vector2i(5, 2)
	var first_type: PieceType.Id = setup.type_at(first)
	var second_type: PieceType.Id = setup.type_at(second)
	setup.swap(first, second)
	assert_eq(setup.type_at(first), second_type)
	assert_eq(setup.type_at(second), first_type)
	assert_true(setup.is_valid())


func test_game_from_setups_places_both_armies_and_red_moves_first() -> void:
	var game: Game = GameFactory.from_setups(
		Setup.random(Side.Id.RED, _rng(1)), Setup.random(Side.Id.GREEN, _rng(2))
	)
	assert_eq(game.board().squares_of(Side.Id.RED).size(), 18)
	assert_eq(game.board().squares_of(Side.Id.GREEN).size(), 18)
	assert_eq(game.side_to_move(), Side.Id.RED)
	assert_false(game.result().is_over())


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
