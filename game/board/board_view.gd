class_name BoardView
extends Control
## Draws the Board from one player's point of view, inside its walnut frame
## with rank numbers on the left and column letters below, and reports taps
## on Squares. Keyboard players move a cursor with the arrow keys, choose with
## Enter or Space and cancel with Escape.

signal square_pressed(square: Vector2i)
## Escape, to drop the selection.
signal cancel_pressed

const LANE_STRIPE: float = 6.0
const ZONE_STRIPE: float = 14.0
const BADGE_FONT_RATIO: float = 0.17
const DESTINATION_DOT: float = 14.0
## The last Move's ring grows this far and fades, once every LAST_MOVE_PERIOD.
const LAST_MOVE_RING_GROWTH: float = 14.0
const LAST_MOVE_PERIOD: float = 2.2
const SELECTION_PERIOD: float = 1.4
## The selected Piece bobs between these heights, at SELECTED_SCALE.
const SELECTED_BOB: Vector2 = Vector2(-4.0, -9.0)
const SELECTED_SCALE: float = 1.07
const PIECE_SHADOW_OFFSET: Vector2 = Vector2(0.0, 5.0)
const PIECE_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.35)
## How visible a Piece is on the target of a Move still on its way.
const PENDING_ALPHA: float = 0.5

## The largest and smallest a Square may be drawn.
@export var max_cell: float = UiTokens.CELL_MATCH
@export var min_cell: float = 40.0

## Stops every looping effect: pulses, bobbing and growing rings.
var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		queue_redraw()

var _state: BoardViewState = BoardViewState.new()
var _geometry: BoardGeometry = null
## Squares whose Piece an animation is drawing instead.
var _hidden_squares: Array[Vector2i] = []
var _cursor: Vector2i = Vector2i(0, Board.ROWS - 1)
@onready var _motion: BoardMotion = BoardMotion.new()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	add_child(_motion)
	_motion.finished.connect(_on_motion_finished)
	resized.connect(_on_resized)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _process(_delta: float) -> void:
	if _is_animating_loops():
		queue_redraw()


func _draw() -> void:
	var geometry: BoardGeometry = geometry()
	_draw_frame(geometry)
	for row: int in Board.ROWS:
		for column: int in Board.COLUMNS:
			_draw_square(Vector2i(column, row), geometry)
	if _state.cover_enemy_zone:
		_draw_enemy_zone(geometry)
	_draw_last_move(geometry)
	_draw_destinations(geometry)
	_draw_selection(geometry)
	for row: int in Board.ROWS:
		for column: int in Board.COLUMNS:
			_draw_piece_on(Vector2i(column, row), geometry)
	_draw_pending_move(geometry)
	_draw_cursor(geometry)
	_draw_labels(geometry)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			var square: Vector2i = geometry().square_at(click.position)
			if Board.is_inside(square):
				_cursor = BoardOrientation.screen_cell_of(square, _state.viewer)
				square_pressed.emit(square)
				accept_event()
		return
	if event.is_action_pressed(&"ui_cancel"):
		cancel_pressed.emit()
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		square_pressed.emit(BoardOrientation.square_at(_cursor, _state.viewer))
		accept_event()
	else:
		_move_cursor(event)


func show_state(state: BoardViewState) -> void:
	_state = state
	_geometry = null
	queue_redraw()


func state() -> BoardViewState:
	return _state


## Where the Board sits in this control right now.
func geometry() -> BoardGeometry:
	if _geometry == null:
		_geometry = BoardGeometry.new(size, max_cell, min_cell, _state.viewer)
	return _geometry


## The smallest size that shows the Board at its smallest Squares.
func _get_minimum_size() -> Vector2:
	return BoardGeometry.new(Vector2.ZERO, min_cell, min_cell, _state.viewer).block_size()


## Animates [param event], which the state shown already includes: the Piece
## glides from its Square to the next, and a Fight plays out between the two.
func play_move(event: PublicMoveEvent) -> void:
	_motion.reduced_motion = reduced_motion
	_hidden_squares = [event.move.from, event.move.to]
	queue_redraw()
	_motion.play_move(event, self)


## Animates two of the viewer's Pieces trading places during Setup.
func play_swap(first: Vector2i, second: Vector2i) -> void:
	_motion.reduced_motion = reduced_motion
	_hidden_squares = [first, second]
	queue_redraw()
	_motion.play_swap(first, second, self)


## The picture of the Piece on [param square] as the viewer sees it now, or
## null when the Square is empty.
## Animates the viewer's Pieces sliding from [param before] to the
## arrangement shown now.
func play_shuffle(before: Board) -> void:
	_motion.reduced_motion = reduced_motion
	_hidden_squares = _state.board.squares_of(_state.viewer)
	queue_redraw()
	_motion.play_shuffle(before, self)


## The global rectangle of the Piece on [param square].
func global_piece_rect(square: Vector2i) -> Rect2:
	var rect: Rect2 = geometry().piece_rect_of(square)
	return Rect2(get_global_transform() * rect.position, rect.size * get_global_transform().get_scale())


func picture_of(square: Vector2i) -> Texture2D:
	var piece: Piece = _state.board.piece_at(square)
	if piece == null:
		return null
	return _texture_for(piece)


## The picture of [param type] of [param side], as the viewer sees it when
## [param revealed] or when it is their own.
func picture_for(type: PieceType.Id, side: Side.Id, revealed: bool) -> Texture2D:
	if revealed or side == _state.viewer or _state.reveal_all:
		return PieceArt.token(type, side, _state.adapted_colours)
	return PieceArt.hidden(side, _state.adapted_colours)


func is_animating() -> bool:
	return not _hidden_squares.is_empty()


func _draw_frame(geometry: BoardGeometry) -> void:
	var frame: StyleBox = get_theme_stylebox(&"panel", &"BoardFrame")
	if frame != null:
		draw_style_box(frame, geometry.frame_rect())
	else:
		draw_rect(geometry.frame_rect(), UiTokens.FRAME_TOP)


func _draw_square(square: Vector2i, geometry: BoardGeometry) -> void:
	var rect: Rect2 = geometry.rect_of(square)
	if Board.is_obstacle(square):
		BoardShapes.draw_stripes(self, rect, UiTokens.LANE_A, UiTokens.LANE_B, LANE_STRIPE)
		return
	var is_dark: bool = (square.x + square.y) % 2 == 0
	draw_rect(rect, UiTokens.CELL_DARK if is_dark else UiTokens.CELL_LIGHT)


## Stripes over the enemy's three rows, with a pill naming them.
func _draw_enemy_zone(geometry: BoardGeometry) -> void:
	# The viewer's Army is always at the bottom, so the enemy's is on top.
	var zone: Rect2 = Rect2(geometry.origin, Vector2(Board.COLUMNS, 3.0) * geometry.cell)
	BoardShapes.draw_stripes(
		self, zone, Color(UiTokens.GREEN_700, 0.3), Color(UiTokens.GREEN_700, 0.18), ZONE_STRIPE
	)
	if _state.enemy_zone_label.is_empty():
		return
	var font: Font = UiFonts.nunito(800)
	var font_size: int = UiTokens.CAPTION
	var text_size: Vector2 = font.get_string_size(_state.enemy_zone_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pill_size: Vector2 = text_size + Vector2(28.0, 12.0)
	var pill: Rect2 = Rect2(zone.get_center() - pill_size / 2.0, pill_size)
	draw_style_box(UiStyles.box(Color(UiTokens.BG_BOTTOM, 0.85), UiTokens.RADIUS_PILL, Vector4i.ZERO, UiTokens.GREEN_500, 1), pill)
	draw_string(
		font, Vector2(pill.position.x + 14.0, pill.position.y + 6.0 + font.get_ascent(font_size)),
		_state.enemy_zone_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, UiTokens.TEXT_PRIMARY
	)


## The Square the last Move left gets a dashed outline; the one it reached
## gets a tint and a ring that grows and fades.
func _draw_last_move(geometry: BoardGeometry) -> void:
	var move: Move = _state.last_move
	if move == null:
		return
	var from: Rect2 = geometry.rect_of(move.from).grow(-6.0)
	BoardShapes.draw_dashed_rect(self, from, Color(UiTokens.GOLD_TEXT, 0.85), 3.0, 8.0)
	var to: Rect2 = geometry.rect_of(move.to)
	draw_rect(to, Color(UiTokens.SELECT_RING, 0.32))
	if reduced_motion:
		return
	var phase: float = fposmod(_seconds(), LAST_MOVE_PERIOD) / LAST_MOVE_PERIOD
	var ring: StyleBoxFlat = BoardShapes.ring(Color(UiTokens.SELECT_RING, 1.0 - phase), 2, UiTokens.RADIUS_M)
	draw_style_box(ring, to.grow(-4.0 + phase * LAST_MOVE_RING_GROWTH))


func _draw_destinations(geometry: BoardGeometry) -> void:
	for square: Vector2i in _state.destinations:
		var rect: Rect2 = geometry.rect_of(square)
		if _state.board.piece_at(square) != null:
			draw_style_box(BoardShapes.ring(UiTokens.RED_400, 3, UiTokens.RADIUS_M), rect.grow(-3.0))
		else:
			draw_circle(rect.get_center(), DESTINATION_DOT / 2.0, UiTokens.GOLD_500, true, -1.0, true)


func _draw_selection(geometry: BoardGeometry) -> void:
	if _state.selected == BoardViewState.NO_SQUARE:
		return
	var glow: float = 0.0 if reduced_motion else (sin(_seconds() * TAU / SELECTION_PERIOD) + 1.0) / 2.0
	var ring: StyleBoxFlat = BoardShapes.ring(
		UiTokens.SELECT_RING, 3, UiTokens.RADIUS_M, Color(UiTokens.SELECT_RING, 0.25 + 0.35 * glow),
		roundi(4.0 + 6.0 * glow)
	)
	draw_style_box(ring, geometry.rect_of(_state.selected).grow(-3.0))


func _draw_piece_on(square: Vector2i, geometry: BoardGeometry) -> void:
	var piece: Piece = _state.board.piece_at(square)
	if piece == null or square in _hidden_squares:
		return
	if _state.pending_move != null and square == _state.pending_move.from:
		return
	var rect: Rect2 = geometry.piece_rect_of(square)
	if square == _state.selected and not reduced_motion:
		var bob: float = (sin(_seconds() * TAU / SELECTION_PERIOD) + 1.0) / 2.0
		var grown: Vector2 = rect.size * SELECTED_SCALE
		rect = Rect2(rect.get_center() - grown / 2.0, grown)
		rect.position.y += lerpf(SELECTED_BOB.x, SELECTED_BOB.y, bob)
	var texture: Texture2D = _texture_for(piece)
	draw_texture_rect(texture, Rect2(rect.position + PIECE_SHADOW_OFFSET, rect.size), false, PIECE_SHADOW)
	draw_texture_rect(texture, rect, false)
	if _shows_type(piece):
		_draw_strength_badge(piece.type, geometry.rect_of(square))


## The Piece of a Move still on its way, faded on its target.
func _draw_pending_move(geometry: BoardGeometry) -> void:
	var move: Move = _state.pending_move
	if move == null:
		return
	var piece: Piece = _state.board.piece_at(move.from)
	if piece == null:
		return
	draw_texture_rect(_texture_for(piece), geometry.piece_rect_of(move.to), false, Color(1.0, 1.0, 1.0, PENDING_ALPHA))


## "attack/defense" in a small dark pill along the bottom of the Square, so
## strengths stay readable on top of the art.
func _draw_strength_badge(type: PieceType.Id, rect: Rect2) -> void:
	var font: Font = UiFonts.nunito(900)
	var font_size: int = roundi(rect.size.x * BADGE_FONT_RATIO)
	var text: String = PieceNames.strengths(type)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var badge_size: Vector2 = Vector2(text_size.x + 10.0, font.get_height(font_size))
	var badge: Rect2 = Rect2(
		Vector2(rect.get_center().x - badge_size.x / 2.0, rect.end.y - badge_size.y - 1.0), badge_size
	)
	draw_style_box(UiStyles.box(Color(UiTokens.BG_BOTTOM, 0.85), UiTokens.RADIUS_PILL), badge)
	draw_string(
		font, badge.position + Vector2(5.0, font.get_ascent(font_size)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, UiTokens.TEXT_PRIMARY
	)


func _draw_cursor(geometry: BoardGeometry) -> void:
	if not has_focus():
		return
	var square: Vector2i = BoardOrientation.square_at(_cursor, _state.viewer)
	draw_style_box(UiStyles.focus_ring(UiTokens.RADIUS_S), geometry.rect_of(square).grow(-5.0))


func _draw_labels(geometry: BoardGeometry) -> void:
	var font: Font = UiFonts.nunito(800)
	var font_size: int = UiTokens.CAPTION
	var half_height: float = (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	for screen_row: int in Board.ROWS:
		var centre: Vector2 = geometry.rank_label_center(screen_row)
		draw_string(
			font, Vector2(centre.x - BoardGeometry.RANK_LABEL_WIDTH / 2.0, centre.y + half_height),
			BoardOrientation.rank_label(screen_row, _state.viewer), HORIZONTAL_ALIGNMENT_CENTER,
			BoardGeometry.RANK_LABEL_WIDTH, font_size, UiTokens.TEXT_MUTED
		)
	for screen_column: int in Board.COLUMNS:
		var centre: Vector2 = geometry.file_label_center(screen_column)
		draw_string(
			font, Vector2(centre.x - geometry.cell / 2.0, centre.y + half_height),
			BoardOrientation.column_label(screen_column, _state.viewer), HORIZONTAL_ALIGNMENT_CENTER,
			geometry.cell, font_size, UiTokens.TEXT_MUTED
		)


func _texture_for(piece: Piece) -> Texture2D:
	return picture_for(piece.type, piece.side, _shows_type(piece))


func _shows_type(piece: Piece) -> bool:
	return _state.reveal_all or piece.side == _state.viewer


func _move_cursor(event: InputEvent) -> void:
	var step: Vector2i = Vector2i.ZERO
	if event.is_action_pressed(&"ui_left", true):
		step = Vector2i.LEFT
	elif event.is_action_pressed(&"ui_right", true):
		step = Vector2i.RIGHT
	elif event.is_action_pressed(&"ui_up", true):
		step = Vector2i.UP
	elif event.is_action_pressed(&"ui_down", true):
		step = Vector2i.DOWN
	if step == Vector2i.ZERO:
		return
	_cursor = Vector2i(
		posmod(_cursor.x + step.x, Board.COLUMNS), posmod(_cursor.y + step.y, Board.ROWS)
	)
	queue_redraw()
	accept_event()


func _is_animating_loops() -> bool:
	if reduced_motion or not is_visible_in_tree():
		return false
	return _state.selected != BoardViewState.NO_SQUARE or _state.last_move != null


func _seconds() -> float:
	return Time.get_ticks_msec() / 1000.0


func _on_resized() -> void:
	_geometry = null
	queue_redraw()


func _on_motion_finished() -> void:
	_hidden_squares.clear()
	queue_redraw()
