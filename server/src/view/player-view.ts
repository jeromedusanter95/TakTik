import type { ReadonlyBoard } from "../rules/board";
import type { GameResult } from "../rules/game-result";
import type { Move } from "../rules/move";
import type { PieceType } from "../rules/piece-type";
import { opponentOf, SIDES, type Side } from "../rules/side";
import { compareSquares, type Square } from "../rules/square";

export interface OwnPiece {
	readonly square: Square;
	readonly type: PieceType;
}

/**
 * What one player may know about a game at a given moment: their own Pieces,
 * the Squares enemy Pieces stand on (never their Piece Types) and the public
 * state. Carries no Piece ids. The referee sends only this to a client.
 */
export interface PlayerView {
	readonly side: Side;
	readonly sideToMove: Side;
	readonly pliesWithoutFight: number;
	readonly result: GameResult;
	readonly ownPieces: readonly OwnPiece[];
	readonly enemySquares: readonly Square[];
	readonly lastMoves: Readonly<Partial<Record<Side, Move>>>;
}

/** The parts of a game a PlayerView is built from. */
export interface ViewableGame {
	readonly board: ReadonlyBoard;
	readonly sideToMove: Side;
	readonly pliesWithoutFight: number;
	readonly result: GameResult;
	lastMoveOf(side: Side): Move | undefined;
}

export function playerViewOf(game: ViewableGame, viewer: Side): PlayerView {
	return {
		side: viewer,
		sideToMove: game.sideToMove,
		pliesWithoutFight: game.pliesWithoutFight,
		result: game.result,
		ownPieces: ownPiecesOf(game.board, viewer),
		enemySquares: sortedSquaresOf(game.board, opponentOf(viewer)),
		lastMoves: lastMovesOf(game),
	};
}

function ownPiecesOf(board: ReadonlyBoard, viewer: Side): OwnPiece[] {
	return sortedSquaresOf(board, viewer).flatMap((square) => {
		const piece = board.pieceAt(square);
		return piece === undefined ? [] : [{ square, type: piece.type }];
	});
}

/** Sorted by Square so the order can never follow Piece ids. */
function sortedSquaresOf(board: ReadonlyBoard, side: Side): Square[] {
	return board.squaresOf(side).toSorted(compareSquares);
}

function lastMovesOf(game: ViewableGame): Partial<Record<Side, Move>> {
	const lastMoves: Partial<Record<Side, Move>> = {};
	for (const side of SIDES) {
		const last = game.lastMoveOf(side);
		if (last !== undefined) {
			lastMoves[side] = last;
		}
	}
	return lastMoves;
}
