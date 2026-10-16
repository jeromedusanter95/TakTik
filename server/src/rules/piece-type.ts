/** The nine Piece Types, their strengths and how many of each an Army holds. */
export type PieceType =
	| "king"
	| "executioner"
	| "knight"
	| "soldier"
	| "magician"
	| "buffoon"
	| "monster"
	| "thief"
	| "princess";

interface PieceTypeTraits {
	readonly attackStrength: number;
	readonly defenseStrength: number;
	readonly armyCount: number;
}

const TRAITS: Readonly<Record<PieceType, PieceTypeTraits>> = {
	king: { attackStrength: 6, defenseStrength: 6, armyCount: 1 },
	executioner: { attackStrength: 5, defenseStrength: 5, armyCount: 1 },
	knight: { attackStrength: 4, defenseStrength: 4, armyCount: 2 },
	soldier: { attackStrength: 3, defenseStrength: 3, armyCount: 3 },
	magician: { attackStrength: 2, defenseStrength: 2, armyCount: 2 },
	buffoon: { attackStrength: 1, defenseStrength: 1, armyCount: 4 },
	monster: { attackStrength: 0, defenseStrength: 7, armyCount: 3 },
	thief: { attackStrength: 7, defenseStrength: 0, armyCount: 1 },
	princess: { attackStrength: 0, defenseStrength: 0, armyCount: 1 },
};

export const PIECE_TYPES: readonly PieceType[] = [
	"king",
	"executioner",
	"knight",
	"soldier",
	"magician",
	"buffoon",
	"monster",
	"thief",
	"princess",
];

export function attackStrengthOf(type: PieceType): number {
	return TRAITS[type].attackStrength;
}

export function defenseStrengthOf(type: PieceType): number {
	return TRAITS[type].defenseStrength;
}

export function armyCountOf(type: PieceType): number {
	return TRAITS[type].armyCount;
}

/** Every Piece Type of one Army, repeated as many times as the Army holds it. */
export function armyTypes(): PieceType[] {
	return PIECE_TYPES.flatMap((type) => Array<PieceType>(armyCountOf(type)).fill(type));
}
