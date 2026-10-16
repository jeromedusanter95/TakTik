class_name PieceArt
extends RefCounted
## The token pictures for every Piece Type of each Army, and the Hidden Piece back.

const _RED_TOKENS: Dictionary[PieceType.Id, Texture2D] = {
	PieceType.Id.KING: preload("res://game/art/king_red.svg"),
	PieceType.Id.EXECUTIONER: preload("res://game/art/executioner_red.svg"),
	PieceType.Id.KNIGHT: preload("res://game/art/knight_red.svg"),
	PieceType.Id.SOLDIER: preload("res://game/art/soldier_red.svg"),
	PieceType.Id.MAGICIAN: preload("res://game/art/magician_red.svg"),
	PieceType.Id.BUFFOON: preload("res://game/art/buffoon_red.svg"),
	PieceType.Id.MONSTER: preload("res://game/art/monster_red.svg"),
	PieceType.Id.THIEF: preload("res://game/art/thief_red.svg"),
	PieceType.Id.PRINCESS: preload("res://game/art/princess_red.svg"),
}
const _GREEN_TOKENS: Dictionary[PieceType.Id, Texture2D] = {
	PieceType.Id.KING: preload("res://game/art/king_green.svg"),
	PieceType.Id.EXECUTIONER: preload("res://game/art/executioner_green.svg"),
	PieceType.Id.KNIGHT: preload("res://game/art/knight_green.svg"),
	PieceType.Id.SOLDIER: preload("res://game/art/soldier_green.svg"),
	PieceType.Id.MAGICIAN: preload("res://game/art/magician_green.svg"),
	PieceType.Id.BUFFOON: preload("res://game/art/buffoon_green.svg"),
	PieceType.Id.MONSTER: preload("res://game/art/monster_green.svg"),
	PieceType.Id.THIEF: preload("res://game/art/thief_green.svg"),
	PieceType.Id.PRINCESS: preload("res://game/art/princess_green.svg"),
}
const _RED_HIDDEN: Texture2D = preload("res://game/art/hidden_red.svg")
const _GREEN_HIDDEN: Texture2D = preload("res://game/art/hidden_green.svg")


static func token(type: PieceType.Id, side: Side.Id) -> Texture2D:
	if side == Side.Id.RED:
		return _RED_TOKENS[type]
	return _GREEN_TOKENS[type]


## The faceless back shown for an enemy piece whose type is still unknown.
static func hidden(side: Side.Id) -> Texture2D:
	return _RED_HIDDEN if side == Side.Id.RED else _GREEN_HIDDEN
