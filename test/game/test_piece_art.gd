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


func test_adapted_colours_turn_the_green_army_blue() -> void:
	var adapted: Texture2D = PieceArt.token(PieceType.Id.SOLDIER, Side.Id.GREEN, true)
	assert_ne(adapted, PieceArt.token(PieceType.Id.SOLDIER, Side.Id.GREEN))
	var image: Image = adapted.get_image()
	var centre_rim: Color = image.get_pixel(floori(image.get_width() / 2.0), roundi(image.get_height() * 0.08))
	assert_gt(centre_rim.b, centre_rim.g, "the rim should be blue, was %s" % centre_rim)


func test_adapted_colours_leave_the_red_army_as_it_is() -> void:
	assert_eq(
		PieceArt.token(PieceType.Id.SOLDIER, Side.Id.RED, true),
		PieceArt.token(PieceType.Id.SOLDIER, Side.Id.RED),
	)


func test_adapted_art_is_made_once() -> void:
	assert_eq(
		PieceArt.hidden(Side.Id.GREEN, true),
		PieceArt.hidden(Side.Id.GREEN, true),
	)
