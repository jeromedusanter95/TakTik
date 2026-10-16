class_name BoardView
extends Control
## Draws the Board from one player's point of view, with column letters below
## and rank numbers on the left, and reports taps on Squares.

signal square_pressed(square: Vector2i)

const PIECE_RADIUS_RATIO: float = 0.42
const STRENGTH_FONT_RATIO: float = 0.17
## The width of the label margins, in Squares.
const LABEL_MARGIN_RATIO: float = 0.4
const LABEL_FONT_RATIO: float = 0.26

@export var palette: BoardPalette = null

var _state: BoardViewState = BoardViewState.new()


func _draw() -> void:
	if palette == null:
		return
	for row: int in Board.ROWS:
		for column: int in Board.COLUMNS:
			_draw_square(Vector2i(column, row))
	_draw_square_labels()


func _gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var click: InputEventMouseButton = event
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var square: Vector2i = _square_at(click.position)
	if Board.is_inside(square):
		square_pressed.emit(square)
		accept_event()


func show_state(state: BoardViewState) -> void:
	_state = state
	queue_redraw()


func _draw_square(square: Vector2i) -> void:
	var rect: Rect2 = _rect_of(square)
	draw_rect(rect, _square_colour(square))
	if _is_last_move_square(square):
		draw_rect(rect, palette.last_move)
	if square in _state.destinations:
		draw_rect(rect, palette.destination)
	if square == _state.selected:
		draw_rect(rect.grow(-2.0), palette.selected, false, 4.0)
	var piece: Piece = _state.board.piece_at(square)
	if piece != null:
		_draw_piece(piece, rect)


func _draw_piece(piece: Piece, rect: Rect2) -> void:
	var token_size: float = rect.size.x * PIECE_RADIUS_RATIO * 2.0
	var token_rect: Rect2 = Rect2(
		rect.get_center() - Vector2(token_size, token_size) / 2.0, Vector2(token_size, token_size)
	)
	if not _state.reveal_all and piece.side != _state.viewer:
		draw_texture_rect(PieceArt.hidden(piece.side), token_rect, false)
		return
	draw_texture_rect(PieceArt.token(piece.type, piece.side), token_rect, false)
	_draw_strength_badge(piece.type, rect)


## "attack/defense" in a small dark pill along the bottom of the Square, so
## strengths stay readable on top of the art.
func _draw_strength_badge(type: PieceType.Id, rect: Rect2) -> void:
	var font_size: int = roundi(rect.size.x * STRENGTH_FONT_RATIO)
	var text: String = PieceNames.strengths(type)
	var font: Font = get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
	)
	var badge_size: Vector2 = text_size + Vector2(8.0, 0.0)
	var badge_position: Vector2 = Vector2(
		rect.get_center().x - badge_size.x / 2.0, rect.end.y - badge_size.y - 1.0
	)
	draw_rect(Rect2(badge_position, badge_size), palette.badge)
	draw_string(
		font, badge_position + Vector2(4.0, font.get_ascent(font_size)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, palette.piece_text
	)


func _draw_square_labels() -> void:
	var font: Font = get_theme_default_font()
	var cell: float = _cell_size()
	var margin: float = cell * LABEL_MARGIN_RATIO
	var font_size: int = roundi(cell * LABEL_FONT_RATIO)
	var origin: Vector2 = _board_origin()
	var baseline_offset: float = (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	for screen_row: int in Board.ROWS:
		var middle_y: float = origin.y + (screen_row + 0.5) * cell
		draw_string(
			font, Vector2(origin.x - margin, middle_y + baseline_offset),
			BoardOrientation.rank_label(screen_row, _state.viewer),
			HORIZONTAL_ALIGNMENT_CENTER, margin, font_size, palette.square_label
		)
	var bottom: float = origin.y + Board.ROWS * cell
	for screen_column: int in Board.COLUMNS:
		draw_string(
			font, Vector2(origin.x + screen_column * cell, bottom + margin / 2.0 + baseline_offset),
			BoardOrientation.column_label(screen_column, _state.viewer),
			HORIZONTAL_ALIGNMENT_CENTER, cell, font_size, palette.square_label
		)


func _square_colour(square: Vector2i) -> Color:
	if Board.is_obstacle(square):
		return palette.obstacle
	var is_dark: bool = (square.x + square.y) % 2 == 0
	return palette.dark_square if is_dark else palette.light_square


func _is_last_move_square(square: Vector2i) -> bool:
	var move: Move = _state.last_move
	return move != null and (square == move.from or square == move.to)


func _cell_size() -> float:
	return minf(
		size.x / (Board.COLUMNS + LABEL_MARGIN_RATIO),
		size.y / (Board.ROWS + LABEL_MARGIN_RATIO),
	)


## The top left corner of the Squares. The rank labels sit to its left and the
## column labels below, and the whole block is centred.
func _board_origin() -> Vector2:
	var cell: float = _cell_size()
	var block_size: Vector2 = Vector2(
		Board.COLUMNS + LABEL_MARGIN_RATIO, Board.ROWS + LABEL_MARGIN_RATIO
	) * cell
	return (size - block_size) / 2.0 + Vector2(cell * LABEL_MARGIN_RATIO, 0.0)


func _rect_of(square: Vector2i) -> Rect2:
	var cell: float = _cell_size()
	var screen_cell: Vector2i = BoardOrientation.screen_cell_of(square, _state.viewer)
	return Rect2(_board_origin() + Vector2(screen_cell) * cell, Vector2(cell, cell))


func _square_at(point: Vector2) -> Vector2i:
	var cell: float = _cell_size()
	var local: Vector2 = (point - _board_origin()) / cell
	var screen_cell: Vector2i = Vector2i(floori(local.x), floori(local.y))
	return BoardOrientation.square_at(screen_cell, _state.viewer)
