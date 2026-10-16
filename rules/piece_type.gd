class_name PieceType
extends RefCounted
## The nine Piece Types, their strengths and how many of each an Army holds.

enum Id {
	KING,
	EXECUTIONER,
	KNIGHT,
	SOLDIER,
	MAGICIAN,
	BUFFOON,
	MONSTER,
	THIEF,
	PRINCESS,
}

const _ATTACK_STRENGTHS: Dictionary[Id, int] = {
	Id.KING: 6,
	Id.EXECUTIONER: 5,
	Id.KNIGHT: 4,
	Id.SOLDIER: 3,
	Id.MAGICIAN: 2,
	Id.BUFFOON: 1,
	Id.MONSTER: 0,
	Id.THIEF: 7,
	Id.PRINCESS: 0,
}

const _DEFENSE_STRENGTHS: Dictionary[Id, int] = {
	Id.KING: 6,
	Id.EXECUTIONER: 5,
	Id.KNIGHT: 4,
	Id.SOLDIER: 3,
	Id.MAGICIAN: 2,
	Id.BUFFOON: 1,
	Id.MONSTER: 7,
	Id.THIEF: 0,
	Id.PRINCESS: 0,
}

const _ARMY_COUNTS: Dictionary[Id, int] = {
	Id.KING: 1,
	Id.EXECUTIONER: 1,
	Id.KNIGHT: 2,
	Id.SOLDIER: 3,
	Id.MAGICIAN: 2,
	Id.BUFFOON: 4,
	Id.MONSTER: 3,
	Id.THIEF: 1,
	Id.PRINCESS: 1,
}


static func attack_strength(type: Id) -> int:
	return _ATTACK_STRENGTHS[type]


static func defense_strength(type: Id) -> int:
	return _DEFENSE_STRENGTHS[type]


static func army_count(type: Id) -> int:
	return _ARMY_COUNTS[type]


## Every Piece Type of one Army, repeated as many times as the Army holds it.
static func army() -> Array[Id]:
	var types: Array[Id] = []
	for type: Id in _ARMY_COUNTS:
		for i: int in _ARMY_COUNTS[type]:
			types.append(type)
	return types
