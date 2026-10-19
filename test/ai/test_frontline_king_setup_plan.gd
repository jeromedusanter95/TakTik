extends GutTest


func test_without_a_base_plan_it_still_arranges_a_whole_army() -> void:
	var plan: FrontlineKingSetupPlan = FrontlineKingSetupPlan.new()
	for side: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 7
		assert_true(plan.arrange(side, rng).is_valid())


func test_the_same_seed_repeats_the_setup() -> void:
	var plan: FrontlineKingSetupPlan = FrontlineKingSetupPlan.new()
	plan.base_plan = GuardedPrincessSetupPlan.new()
	for side: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
		var first_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		first_rng.seed = 9
		var second_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		second_rng.seed = 9
		var first: Setup = plan.arrange(side, first_rng)
		var second: Setup = plan.arrange(side, second_rng)
		for square: Vector2i in Setup.squares_for(side):
			assert_eq(first.type_at(square), second.type_at(square))
