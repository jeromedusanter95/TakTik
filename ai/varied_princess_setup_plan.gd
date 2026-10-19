class_name VariedPrincessSetupPlan
extends SetupPlan
## Keeps the Princess on the Home Row with a chosen number of Monster guards.
## The remaining Monsters are placed elsewhere, then the mobile Pieces shuffle.

@export_range(0, 3) var monster_guards: int = 1


func arrange(side: Side.Id, rng: RandomNumberGenerator) -> Setup:
	var setup: Setup = Setup.new(side)
	var princess: Vector2i = Vector2i(
		rng.randi_range(0, Board.COLUMNS - 1), Board.home_row(side)
	)
	setup.place(princess, PieceType.Id.PRINCESS)
	_arrange_monsters(setup, princess, rng)
	_fill_mobile_pieces(setup, _free_squares(setup), rng)
	return setup


func _arrange_monsters(setup: Setup, princess: Vector2i, rng: RandomNumberGenerator) -> void:
	var neighbours: Array[Vector2i] = []
	neighbours.assign(Board.steps_from(princess))
	var guards: int = clampi(monster_guards, 0, neighbours.size())
	_place_monsters(setup, _random_squares(neighbours, guards, rng))
	var outside: Array[Vector2i] = []
	for square: Vector2i in _free_squares(setup):
		if not neighbours.has(square):
			outside.append(square)
	var remaining: int = PieceType.army_count(PieceType.Id.MONSTER) - guards
	_place_monsters(setup, _random_squares(outside, remaining, rng))


func _place_monsters(setup: Setup, squares: Array[Vector2i]) -> void:
	for square: Vector2i in squares:
		setup.place(square, PieceType.Id.MONSTER)


func _random_squares(
		candidates: Array[Vector2i], count: int, rng: RandomNumberGenerator,
) -> Array[Vector2i]:
	var pool: Array[Vector2i] = candidates.duplicate()
	var chosen: Array[Vector2i] = []
	for _index: int in count:
		var square: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
		chosen.append(square)
		pool.erase(square)
	return chosen


func _fill_mobile_pieces(
		setup: Setup, free: Array[Vector2i], rng: RandomNumberGenerator,
) -> void:
	for type: PieceType.Id in PieceType.army():
		if type == PieceType.Id.PRINCESS or type == PieceType.Id.MONSTER:
			continue
		var square: Vector2i = free[rng.randi_range(0, free.size() - 1)]
		setup.place(square, type)
		free.erase(square)


func _free_squares(setup: Setup) -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	for square: Vector2i in Setup.squares_for(setup.side):
		if not setup.has_piece(square):
			free.append(square)
	return free
