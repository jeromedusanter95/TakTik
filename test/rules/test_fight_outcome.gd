extends GutTest


func test_only_a_magician_beats_a_monster() -> void:
	for attacker: PieceType.Id in PieceType.Id.values():
		var expected: FightOutcome.Id = (
			FightOutcome.Id.ATTACKER_WINS if attacker == PieceType.Id.MAGICIAN
			else FightOutcome.Id.DEFENDER_WINS
		)
		assert_eq(FightOutcome.resolve(attacker, PieceType.Id.MONSTER), expected, "attacker %d" % attacker)


func test_a_thief_beats_every_piece_but_a_monster() -> void:
	for defender: PieceType.Id in PieceType.Id.values():
		if defender == PieceType.Id.MONSTER:
			continue
		assert_eq(
			FightOutcome.resolve(PieceType.Id.THIEF, defender),
			FightOutcome.Id.ATTACKER_WINS,
			"defender %d" % defender
		)


func test_the_army_holds_18_pieces() -> void:
	assert_eq(PieceType.army().size(), 18)
