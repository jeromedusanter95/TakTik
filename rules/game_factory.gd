class_name GameFactory
extends RefCounted
## Builds a new Game from both players' Setups.


## Piece ids follow Square order, never placement order, so an id can never
## hint at a Piece Type.
static func from_setups(red: Setup, green: Setup) -> Game:
	var board: Board = Board.new()
	var next_id: int = 0
	for setup: Setup in [red, green]:
		for square: Vector2i in Setup.squares_for(setup.side):
			if setup.has_piece(square):
				board.place(Piece.new(next_id, setup.type_at(square), setup.side), square)
				next_id += 1
	return Game.new(board, Side.Id.RED)
