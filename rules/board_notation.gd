class_name BoardNotation
extends RefCounted
## Reads and writes the text notation of spec/rules/README.md: squares like
## "c3", moves like "c3-c4" and Boards as 8 strings from rank 8 down to rank 1.

const EMPTY: String = "."
const OBSTACLE: String = "#"
const _LETTERS: Dictionary[PieceType.Id, String] = {
	PieceType.Id.KING: "K",
	PieceType.Id.EXECUTIONER: "E",
	PieceType.Id.KNIGHT: "N",
	PieceType.Id.SOLDIER: "S",
	PieceType.Id.MAGICIAN: "M",
	PieceType.Id.BUFFOON: "B",
	PieceType.Id.MONSTER: "O",
	PieceType.Id.THIEF: "T",
	PieceType.Id.PRINCESS: "P",
}
const _COLUMN_LETTERS: String = "abcdef"


static func parse_square(text: String) -> Vector2i:
	return Vector2i(_COLUMN_LETTERS.find(text[0]), int(text.substr(1)) - 1)


static func format_square(square: Vector2i) -> String:
	return "%s%d" % [_COLUMN_LETTERS[square.x], square.y + 1]


static func parse_move(text: String) -> Move:
	var parts: PackedStringArray = text.split("-")
	return Move.new(parse_square(parts[0]), parse_square(parts[1]))


static func letter_of(piece: Piece) -> String:
	var letter: String = _LETTERS[piece.type]
	return letter if piece.side == Side.Id.RED else letter.to_lower()


## The Piece Type a letter names, or -1 when it names none.
static func type_of_letter(letter: String) -> int:
	for type: PieceType.Id in _LETTERS:
		if _LETTERS[type] == letter.to_upper():
			return type
	return -1


static func side_of_letter(letter: String) -> Side.Id:
	return Side.Id.RED if letter == letter.to_upper() else Side.Id.GREEN


static func parse_board(rows: Array[String]) -> Board:
	var board: Board = Board.new()
	var next_id: int = 0
	for index: int in rows.size():
		var row: int = Board.ROWS - 1 - index
		for column: int in Board.COLUMNS:
			var letter: String = rows[index][column]
			var type: int = type_of_letter(letter)
			if type == -1:
				continue
			var piece: Piece = Piece.new(next_id, type as PieceType.Id, side_of_letter(letter))
			board.place(piece, Vector2i(column, row))
			next_id += 1
	return board


static func format_board(board: Board) -> Array[String]:
	var rows: Array[String] = []
	for row: int in range(Board.ROWS - 1, -1, -1):
		var text: String = ""
		for column: int in Board.COLUMNS:
			text += _character_at(board, Vector2i(column, row))
		rows.append(text)
	return rows


## Reads [param rows], the side's setup ranks from top to bottom.
static func parse_setup(owner: Side.Id, rows: Array[String]) -> Setup:
	var setup: Setup = Setup.new(owner)
	var setup_rows: Array[int] = Setup.rows_for(owner)
	for index: int in rows.size():
		var row: int = setup_rows[setup_rows.size() - 1 - index]
		for column: int in Board.COLUMNS:
			var letter: String = rows[index][column]
			var type: int = type_of_letter(letter)
			if type == -1 or side_of_letter(letter) != owner:
				continue
			setup.place(Vector2i(column, row), type as PieceType.Id)
	return setup


static func _character_at(board: Board, square: Vector2i) -> String:
	if Board.is_obstacle(square):
		return OBSTACLE
	var piece: Piece = board.piece_at(square)
	return EMPTY if piece == null else letter_of(piece)
