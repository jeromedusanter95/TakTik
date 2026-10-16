import type { Board, ReadonlyBoard } from "./board";
import type { Fight } from "./fight";
import { resolveFight } from "./fight-outcome";
import { IN_PROGRESS, isOver, type GameResult } from "./game-result";
import type { Move } from "./move";
import type { MoveRecord } from "./move-record";
import { movementRuleFor } from "./movement-catalog";
import type { Piece } from "./piece";
import { opponentOf, type Side } from "./side";
import { sameSquare, type Square } from "./square";
import { judgeAfterMove, type PositionAfterMove } from "./victory-judge";

/** Where a game stands when it is created. The Game keeps its own copy of [board]. */
export interface GameStart {
	readonly board: Board;
	readonly sideToMove: Side;
	readonly pliesWithoutFight?: number;
	readonly lastMoveBySide?: Readonly<Partial<Record<Side, Move>>>;
}

/** The answer to a Move: played, with what happened, or rejected, with nothing changed. */
export type MoveAttempt = { readonly accepted: true; readonly record: MoveRecord } | { readonly accepted: false };

/** One game being played: the Board, whose turn it is and how it ended. */
export class Game implements PositionAfterMove {
	private readonly pieces: Board;
	private toMove: Side;
	private plies: number;
	private readonly lastMoves: Map<Side, Move>;
	private outcome: GameResult = IN_PROGRESS;

	constructor(start: GameStart) {
		this.pieces = start.board.copy();
		this.toMove = start.sideToMove;
		this.plies = start.pliesWithoutFight ?? 0;
		this.lastMoves = new Map(Object.entries(start.lastMoveBySide ?? {}) as [Side, Move][]);
	}

	get board(): ReadonlyBoard {
		return this.pieces;
	}

	get sideToMove(): Side {
		return this.toMove;
	}

	get pliesWithoutFight(): number {
		return this.plies;
	}

	get result(): GameResult {
		return this.outcome;
	}

	/** The last Move [side] played, or undefined before its first Move. Public: both players saw it. */
	lastMoveOf(side: Side): Move | undefined {
		return this.lastMoves.get(side);
	}

	/** An independent copy, for exploring Moves without touching this game. */
	copy(): Game {
		const copy = new Game({
			board: this.pieces,
			sideToMove: this.toMove,
			pliesWithoutFight: this.plies,
			lastMoveBySide: Object.fromEntries(this.lastMoves),
		});
		copy.outcome = this.outcome;
		return copy;
	}

	legalDestinations(from: Square): Square[] {
		const piece = this.pieces.pieceAt(from);
		if (isOver(this.outcome) || piece === undefined || piece.side !== this.toMove) {
			return [];
		}
		const reachable = movementRuleFor(piece.type).destinations(from, this.pieces, piece.side);
		return reachable.filter((to) => !this.isForbiddenMoveBack(piece.side, from, to));
	}

	legalMoves(): Move[] {
		return this.pieces
			.squaresOf(this.toMove)
			.flatMap((from) => this.legalDestinations(from).map((to) => ({ from, to })));
	}

	hasLegalMove(): boolean {
		return this.pieces.squaresOf(this.toMove).some((from) => this.legalDestinations(from).length > 0);
	}

	isLegal(move: Move): boolean {
		return this.legalDestinations(move.from).some((to) => sameSquare(to, move.to));
	}

	tryPlay(move: Move): MoveAttempt {
		if (!this.isLegal(move)) {
			return { accepted: false };
		}
		const record = this.play(move);
		this.outcome = judgeAfterMove(this, record);
		return { accepted: true, record };
	}

	private play(move: Move): MoveRecord {
		const mover = this.pieceToMove(move.from);
		const fight = this.resolveOnBoard(move, mover);
		this.plies = fight === undefined ? this.plies + 1 : 0;
		this.lastMoves.set(mover.side, move);
		this.toMove = opponentOf(this.toMove);
		return fight === undefined ? { move, mover } : { move, mover, fight };
	}

	private pieceToMove(from: Square): Piece {
		const piece = this.pieces.pieceAt(from);
		if (piece === undefined) {
			throw new Error("A legal Move always starts from a Piece");
		}
		return piece;
	}

	private resolveOnBoard(move: Move, attacker: Piece): Fight | undefined {
		const defender = this.pieces.pieceAt(move.to);
		if (defender === undefined) {
			this.pieces.relocate(move.from, move.to);
			return undefined;
		}
		const fight: Fight = { attacker, defender, outcome: resolveFight(attacker.type, defender.type) };
		this.applyFight(move, fight);
		return fight;
	}

	private applyFight(move: Move, fight: Fight): void {
		switch (fight.outcome) {
			case "attacker_wins":
				this.pieces.remove(move.to);
				this.pieces.relocate(move.from, move.to);
				return;
			case "defender_wins":
				this.pieces.remove(move.from);
				return;
			case "both_eliminated":
				this.pieces.remove(move.from);
				this.pieces.remove(move.to);
				return;
		}
	}

	/** The Move Back rule: a Piece may not return to the exact Square it left on its owner's very next turn. */
	private isForbiddenMoveBack(side: Side, from: Square, to: Square): boolean {
		const last = this.lastMoves.get(side);
		return last !== undefined && sameSquare(last.to, from) && sameSquare(last.from, to);
	}
}
