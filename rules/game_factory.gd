class_name GameFactory
extends RefCounted
## Builds a new Game from both players' Setups.


static func from_setups(red: Setup, green: Setup) -> Game:
	var board: Board = Board.new()
	var next_id: int = 0
	for setup: Setup in [red, green]:
		for square: Vector2i in setup.squares():
			board.place(Piece.new(next_id, setup.type_at(square), setup.side), square)
			next_id += 1
	return Game.new(board, Side.Id.RED)
