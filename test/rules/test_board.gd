extends GutTest
## Board behaviour not covered by the shared rule cases of res://spec/rules/.


func test_pieces_lists_every_piece_by_square() -> void:
	var rows: Array[String] = ["....k.", "......", "......", ".#..#.", ".#..#.", "......", "......", "K....P"]
	var board: Board = BoardNotation.parse_board(rows)
	var pieces: Dictionary[Vector2i, Piece] = board.pieces()
	assert_eq(pieces.size(), 3)
	assert_eq(pieces[Vector2i(0, 0)].type, PieceType.Id.KING)
	assert_eq(pieces[Vector2i(5, 0)].type, PieceType.Id.PRINCESS)
	assert_eq(pieces[Vector2i(4, 7)].side, Side.Id.GREEN)
