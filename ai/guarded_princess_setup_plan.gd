class_name GuardedPrincessSetupPlan
extends SetupPlan
## Hides the Princess on a random Square of the Home Row with Monsters on
## the Squares next to her, as a careful player would, so only a Magician can
## open the way. The other Pieces are shuffled over the Squares left.


func arrange(side: Side.Id, rng: RandomNumberGenerator) -> Setup:
	var setup: Setup = Setup.new(side)
	var princess: Vector2i = Vector2i(
		rng.randi_range(0, Board.COLUMNS - 1), Board.home_row(side)
	)
	setup.place(princess, PieceType.Id.PRINCESS)
	var others: Array[PieceType.Id] = PieceType.army()
	others.erase(PieceType.Id.PRINCESS)
	for guard: Vector2i in _guard_squares(setup, princess):
		if others.has(PieceType.Id.MONSTER):
			setup.place(guard, PieceType.Id.MONSTER)
			others.erase(PieceType.Id.MONSTER)
	var free: Array[Vector2i] = []
	for square: Vector2i in Setup.squares_for(side):
		if not setup.has_piece(square):
			free.append(square)
	for type: PieceType.Id in others:
		var index: int = rng.randi_range(0, free.size() - 1)
		setup.place(free[index], type)
		free.remove_at(index)
	return setup


## The setup Squares one step from [param princess].
static func _guard_squares(setup: Setup, princess: Vector2i) -> Array[Vector2i]:
	var guards: Array[Vector2i] = []
	for target: Vector2i in Board.steps_from(princess):
		if setup.is_setup_square(target):
			guards.append(target)
	return guards
