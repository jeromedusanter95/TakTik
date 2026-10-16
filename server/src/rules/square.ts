/**
 * One cell of the Board. Column 0 is "a", row 0 is rank 1, Red's Home Row.
 * The same shape also describes a direction of travel between Squares.
 */
export interface Square {
	readonly column: number;
	readonly row: number;
}

export function squareAt(column: number, row: number): Square {
	return { column, row };
}

export function sameSquare(first: Square, second: Square): boolean {
	return first.column === second.column && first.row === second.row;
}

export function stepFrom(square: Square, direction: Square): Square {
	return squareAt(square.column + direction.column, square.row + direction.row);
}

/** Orders Squares by column, then by row, so listings never follow hidden data. */
export function compareSquares(first: Square, second: Square): number {
	return first.column - second.column || first.row - second.row;
}
