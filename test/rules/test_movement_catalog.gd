extends GutTest
## What each Piece Type's movement says about itself, as the rules page reads
## it.


func test_the_monster_never_moves_nor_attacks() -> void:
	var rule: MovementRule = MovementCatalog.rule_for(PieceType.Id.MONSTER)
	assert_eq(rule.reach(), MovementRule.Reach.NONE)
	assert_false(rule.can_attack())


func test_the_buffoon_crosses_any_number_of_squares_and_attacks() -> void:
	var rule: MovementRule = MovementCatalog.rule_for(PieceType.Id.BUFFOON)
	assert_eq(rule.reach(), MovementRule.Reach.ANY_SQUARES)
	assert_true(rule.can_attack())


func test_the_princess_steps_one_square_but_never_attacks() -> void:
	var rule: MovementRule = MovementCatalog.rule_for(PieceType.Id.PRINCESS)
	assert_eq(rule.reach(), MovementRule.Reach.ONE_SQUARE)
	assert_false(rule.can_attack())


func test_the_other_pieces_step_one_square_and_attack() -> void:
	for type: PieceType.Id in [
		PieceType.Id.KING,
		PieceType.Id.EXECUTIONER,
		PieceType.Id.KNIGHT,
		PieceType.Id.SOLDIER,
		PieceType.Id.MAGICIAN,
		PieceType.Id.THIEF,
	]:
		var rule: MovementRule = MovementCatalog.rule_for(type)
		assert_eq(rule.reach(), MovementRule.Reach.ONE_SQUARE, "type %d" % type)
		assert_true(rule.can_attack(), "type %d" % type)
