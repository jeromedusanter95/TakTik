extends GutTest
## The piece cards' order and their "Beats when attacking" lists, in the
## same order.


func test_pieces_are_sorted_by_attack_highest_first() -> void:
	var expected: Array[PieceType.Id] = [
		PieceType.Id.THIEF,
		PieceType.Id.KING,
		PieceType.Id.EXECUTIONER,
		PieceType.Id.KNIGHT,
		PieceType.Id.SOLDIER,
		PieceType.Id.MAGICIAN,
		PieceType.Id.BUFFOON,
		PieceType.Id.MONSTER,
		PieceType.Id.PRINCESS,
	]
	assert_eq(PieceGuide.by_attack(), expected)


func test_the_magician_beats_the_monster_and_weaker_defenses() -> void:
	var expected: Array[PieceType.Id] = [
		PieceType.Id.THIEF,
		PieceType.Id.BUFFOON,
		PieceType.Id.MONSTER,
		PieceType.Id.PRINCESS,
	]
	assert_eq(PieceGuide.beaten_by(PieceType.Id.MAGICIAN), expected)


func test_the_thief_beats_everyone_but_the_monster() -> void:
	var beaten: Array[PieceType.Id] = PieceGuide.beaten_by(PieceType.Id.THIEF)
	assert_eq(beaten.size(), 8)
	assert_false(beaten.has(PieceType.Id.MONSTER))


func test_pieces_that_never_attack_beat_nobody() -> void:
	assert_eq(PieceGuide.beaten_by(PieceType.Id.MONSTER), [] as Array[PieceType.Id])
	assert_eq(PieceGuide.beaten_by(PieceType.Id.PRINCESS), [] as Array[PieceType.Id])
