class_name FrontlineKingSetupPlan
extends SetupPlan
## Places the King on the front line in a lane that opens into the middle rows.
## The base plan arranges the rest of the Army; null shuffles it at random.

@export var base_plan: SetupPlan = null


func arrange(side: Side.Id, rng: RandomNumberGenerator) -> Setup:
	var setup: Setup = (
		base_plan.arrange(side, rng) if base_plan != null else Setup.random(side, rng)
	)
	var front: Array[Vector2i] = _open_front_squares(side)
	var mobile: Array[Vector2i] = []
	for square: Vector2i in front:
		if setup.type_at(square) != PieceType.Id.MONSTER:
			mobile.append(square)
	if not mobile.is_empty():
		front = mobile
	setup.swap(_king_square(setup), front[rng.randi_range(0, front.size() - 1)])
	return setup


func _open_front_squares(side: Side.Id) -> Array[Vector2i]:
	var forward: int = 1 if side == Side.Id.RED else -1
	var row: int = Board.home_row(side) + forward * (Setup.SETUP_ROW_COUNT - 1)
	var squares: Array[Vector2i] = []
	for column: int in Board.COLUMNS:
		if not Board.is_obstacle(Vector2i(column, row + forward)):
			squares.append(Vector2i(column, row))
	return squares


func _king_square(setup: Setup) -> Vector2i:
	for square: Vector2i in setup.squares():
		if setup.type_at(square) == PieceType.Id.KING:
			return square
	return Vector2i(-1, -1)
