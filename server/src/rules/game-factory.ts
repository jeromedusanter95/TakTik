import { Board } from "./board";
import { Game } from "./game";
import { Setup } from "./setup";

/**
 * A new Game from both players' valid Setups, Red to move. Piece ids follow
 * Square order, never placement order, so an id can never hint at a Piece Type.
 */
export function gameFromSetups(red: Setup, green: Setup): Game {
	const board = new Board();
	let nextId = 0;
	for (const setup of [red, green]) {
		for (const square of Setup.squaresFor(setup.side)) {
			const type = setup.typeAt(square);
			if (type !== undefined) {
				board.place({ id: nextId++, type, side: setup.side }, square);
			}
		}
	}
	return new Game({ board, sideToMove: "red" });
}
