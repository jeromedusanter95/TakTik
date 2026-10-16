extends GutTest


func test_every_piece_type_of_each_side_has_a_token() -> void:
	for side: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
		for type: PieceType.Id in PieceType.Id.values():
			assert_not_null(PieceArt.token(type, side), "%s %s" % [type, side])


func test_red_and_green_tokens_differ() -> void:
	for type: PieceType.Id in PieceType.Id.values():
		assert_ne(
			PieceArt.token(type, Side.Id.RED),
			PieceArt.token(type, Side.Id.GREEN),
		)


func test_every_piece_type_has_its_own_token() -> void:
	var seen: Array[Texture2D] = []
	for type: PieceType.Id in PieceType.Id.values():
		var texture: Texture2D = PieceArt.token(type, Side.Id.RED)
		assert_false(seen.has(texture), "duplicate token for %s" % type)
		seen.append(texture)


func test_each_side_has_a_hidden_back() -> void:
	assert_not_null(PieceArt.hidden(Side.Id.RED))
	assert_not_null(PieceArt.hidden(Side.Id.GREEN))
	assert_ne(PieceArt.hidden(Side.Id.RED), PieceArt.hidden(Side.Id.GREEN))
