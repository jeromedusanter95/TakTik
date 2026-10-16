class_name MovementCatalog
extends RefCounted
## Which MovementRule each Piece Type follows.

static var _still: MovementRule = StillMovement.new()
static var _slide: MovementRule = SlideMovement.new()
static var _step: MovementRule = StepMovement.new(true)
static var _step_without_attack: MovementRule = StepMovement.new(false)


static func rule_for(type: PieceType.Id) -> MovementRule:
	match type:
		PieceType.Id.MONSTER:
			return _still
		PieceType.Id.BUFFOON:
			return _slide
		PieceType.Id.PRINCESS:
			return _step_without_attack
		_:
			return _step
