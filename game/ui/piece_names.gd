class_name PieceNames
extends RefCounted
## The words players read for each Piece Type and side, in the current
## language.

const _NAME_KEYS: Dictionary[PieceType.Id, StringName] = {
	PieceType.Id.KING: &"PIECE_KING",
	PieceType.Id.EXECUTIONER: &"PIECE_EXECUTIONER",
	PieceType.Id.KNIGHT: &"PIECE_KNIGHT",
	PieceType.Id.SOLDIER: &"PIECE_SOLDIER",
	PieceType.Id.MAGICIAN: &"PIECE_MAGICIAN",
	PieceType.Id.BUFFOON: &"PIECE_BUFFOON",
	PieceType.Id.MONSTER: &"PIECE_MONSTER",
	PieceType.Id.THIEF: &"PIECE_THIEF",
	PieceType.Id.PRINCESS: &"PIECE_PRINCESS",
}


static func display_name(type: PieceType.Id) -> String:
	return Translated.text(_NAME_KEYS[type])


## "attack/defense", for example "4/4".
static func strengths(type: PieceType.Id) -> String:
	return "%d/%d" % [PieceType.attack_strength(type), PieceType.defense_strength(type)]


static func side_name(side: Side.Id) -> String:
	return Translated.text(&"SIDE_RED" if side == Side.Id.RED else &"SIDE_GREEN")
