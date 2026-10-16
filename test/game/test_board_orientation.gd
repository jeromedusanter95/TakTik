extends GutTest
## The Board is turned so each viewer's Home Row is at the bottom, and the
## square labels turn with it so a named Square can be found on screen.


func test_red_sees_a1_bottom_left() -> void:
	assert_eq(BoardOrientation.screen_cell_of(Vector2i(0, 0), Side.Id.RED), Vector2i(0, 7))


func test_green_sees_f8_bottom_left() -> void:
	assert_eq(BoardOrientation.screen_cell_of(Vector2i(5, 7), Side.Id.GREEN), Vector2i(0, 7))


func test_square_at_undoes_screen_cell_of_for_both_viewers() -> void:
	for viewer: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
		for row: int in Board.ROWS:
			for column: int in Board.COLUMNS:
				var square: Vector2i = Vector2i(column, row)
				var cell: Vector2i = BoardOrientation.screen_cell_of(square, viewer)
				assert_eq(BoardOrientation.square_at(cell, viewer), square)


func test_red_reads_columns_a_to_f_and_ranks_8_down_to_1() -> void:
	assert_eq(_columns(Side.Id.RED), "abcdef")
	assert_eq(_ranks(Side.Id.RED), "87654321")


func test_green_reads_columns_f_to_a_and_ranks_1_down_to_8() -> void:
	assert_eq(_columns(Side.Id.GREEN), "fedcba")
	assert_eq(_ranks(Side.Id.GREEN), "12345678")


func test_labels_name_the_square_drawn_at_their_column_and_row() -> void:
	for viewer: Side.Id in [Side.Id.RED, Side.Id.GREEN]:
		var cell: Vector2i = Vector2i(2, 5)
		var name: String = (
			BoardOrientation.column_label(cell.x, viewer)
			+ BoardOrientation.rank_label(cell.y, viewer)
		)
		assert_eq(name, BoardNotation.format_square(BoardOrientation.square_at(cell, viewer)))


func _columns(viewer: Side.Id) -> String:
	var text: String = ""
	for column: int in Board.COLUMNS:
		text += BoardOrientation.column_label(column, viewer)
	return text


func _ranks(viewer: Side.Id) -> String:
	var text: String = ""
	for row: int in Board.ROWS:
		text += BoardOrientation.rank_label(row, viewer)
	return text
