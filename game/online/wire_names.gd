class_name WireNames
extends RefCounted
## The names the online server uses for Sides, Piece Types, Fight outcomes
## and game results, matched to the client's enums.

const _SIDES: Dictionary[String, Side.Id] = {
	"red": Side.Id.RED,
	"green": Side.Id.GREEN,
}

const _PIECE_TYPES: Dictionary[String, PieceType.Id] = {
	"king": PieceType.Id.KING,
	"executioner": PieceType.Id.EXECUTIONER,
	"knight": PieceType.Id.KNIGHT,
	"soldier": PieceType.Id.SOLDIER,
	"magician": PieceType.Id.MAGICIAN,
	"buffoon": PieceType.Id.BUFFOON,
	"monster": PieceType.Id.MONSTER,
	"thief": PieceType.Id.THIEF,
	"princess": PieceType.Id.PRINCESS,
}

const _OUTCOMES: Dictionary[String, FightOutcome.Id] = {
	"attacker_wins": FightOutcome.Id.ATTACKER_WINS,
	"defender_wins": FightOutcome.Id.DEFENDER_WINS,
	"both_eliminated": FightOutcome.Id.BOTH_ELIMINATED,
}

const _STATUSES: Dictionary[String, GameResult.Status] = {
	"in_progress": GameResult.Status.IN_PROGRESS,
	"red_wins": GameResult.Status.RED_WINS,
	"green_wins": GameResult.Status.GREEN_WINS,
	"draw": GameResult.Status.DRAW,
}

const _REASONS: Dictionary[String, GameResult.Reason] = {
	"none": GameResult.Reason.NONE,
	"princess_captured": GameResult.Reason.PRINCESS_CAPTURED,
	"princess_reached_home_row": GameResult.Reason.PRINCESS_REACHED_HOME_ROW,
	"blocked": GameResult.Reason.BLOCKED,
	"no_fight_limit": GameResult.Reason.NO_FIGHT_LIMIT,
	"resigned": GameResult.Reason.RESIGNED,
	"forfeited": GameResult.Reason.FORFEITED,
}


static func is_side(name: Variant) -> bool:
	return name is String and _SIDES.has(name)


## [param name] must pass the matching is_ check.
static func side(name: Variant) -> Side.Id:
	var key: String = name
	return _SIDES[key]


static func side_name(value: Side.Id) -> String:
	return _SIDES.find_key(value)


static func is_piece_type(name: Variant) -> bool:
	return name is String and _PIECE_TYPES.has(name)


## [param name] must pass the matching is_ check.
static func piece_type(name: Variant) -> PieceType.Id:
	var key: String = name
	return _PIECE_TYPES[key]


static func piece_type_name(value: PieceType.Id) -> String:
	return _PIECE_TYPES.find_key(value)


static func is_outcome(name: Variant) -> bool:
	return name is String and _OUTCOMES.has(name)


## [param name] must pass the matching is_ check.
static func outcome(name: Variant) -> FightOutcome.Id:
	var key: String = name
	return _OUTCOMES[key]


static func is_status(name: Variant) -> bool:
	return name is String and _STATUSES.has(name)


## [param name] must pass the matching is_ check.
static func status(name: Variant) -> GameResult.Status:
	var key: String = name
	return _STATUSES[key]


static func is_reason(name: Variant) -> bool:
	return name is String and _REASONS.has(name)


## [param name] must pass the matching is_ check.
static func reason(name: Variant) -> GameResult.Reason:
	var key: String = name
	return _REASONS[key]
