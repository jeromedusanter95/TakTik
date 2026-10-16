class_name PieceNames
extends RefCounted
## The words players read for each Piece Type.

const _NAMES: Dictionary[PieceType.Id, String] = {
	PieceType.Id.KING: "King",
	PieceType.Id.EXECUTIONER: "Executioner",
	PieceType.Id.KNIGHT: "Knight",
	PieceType.Id.SOLDIER: "Soldier",
	PieceType.Id.MAGICIAN: "Magician",
	PieceType.Id.BUFFOON: "Buffoon",
	PieceType.Id.MONSTER: "Monster",
	PieceType.Id.THIEF: "Thief",
	PieceType.Id.PRINCESS: "Princess",
}


static func display_name(type: PieceType.Id) -> String:
	return _NAMES[type]


## "attack/defense", for example "4/4".
static func strengths(type: PieceType.Id) -> String:
	return "%d/%d" % [PieceType.attack_strength(type), PieceType.defense_strength(type)]


static func side_name(side: Side.Id) -> String:
	return "Red" if side == Side.Id.RED else "Green"
