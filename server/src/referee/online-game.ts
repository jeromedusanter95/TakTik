import type { Game } from "../rules/game";
import { gameFromSetups } from "../rules/game-factory";
import { isOver, type ConcessionReason } from "../rules/game-result";
import type { Move } from "../rules/move";
import { Setup, type SetupDraws } from "../rules/setup";
import { opponentOf, SIDES, type Side } from "../rules/side";
import { compareSquares, sameSquare } from "../rules/square";
import { playerViewOf, type PlayerView } from "../view/player-view";
import { publicMoveEventOf, type PublicMoveEvent } from "../view/public-move-event";
import type { Placement, RefereeRefusal, ShownPiece } from "./protocol";
import type { Seating } from "./seating";

export type OnlinePhase = "setup" | "playing" | "over";

export type SetupAttempt = { readonly accepted: true } | { readonly accepted: false; readonly reason: RefereeRefusal };

export type ConcessionAttempt = { readonly accepted: true } | { readonly accepted: false; readonly reason: RefereeRefusal };

/** A player who gave the game away, by Resigning or by Forfeiting. */
export interface Concession {
	readonly loser: Side;
	readonly reason: ConcessionReason;
}

export type OnlineMoveAttempt =
	| { readonly accepted: true; readonly event: PublicMoveEvent }
	| { readonly accepted: false; readonly reason: RefereeRefusal };

/**
 * Everything needed to rebuild an online game: who sits where, each Setup
 * handed in, every Move played, in order, and who Resigned or Forfeited, if
 * anyone did. Plain data, so it can be stored.
 */
export interface GameRecord {
	readonly seating: Seating;
	readonly setups: Readonly<Partial<Record<Side, readonly Placement[]>>>;
	readonly moves: readonly Move[];
	readonly concession?: Concession;
}

/** A valid Setup, kept with the placements it was handed in as, for the record. */
interface HandedInSetup {
	readonly placements: readonly Placement[];
	readonly setup: Setup;
}

/**
 * One online game as the referee sees it: both Setups, then the game played
 * with the rules, and what each player may learn of it. Holds no connection.
 */
export class OnlineGame {
	private readonly setups = new Map<Side, HandedInSetup>();
	private readonly moves: Move[] = [];
	private readonly events: PublicMoveEvent[] = [];
	private game: Game | undefined;
	private concession: Concession | undefined;

	private constructor(private readonly seating: Seating) {}

	static open(seating: Seating): OnlineGame {
		return new OnlineGame(seating);
	}

	/** Throws when the record does not replay as a game of the rules. */
	static fromRecord(record: GameRecord): OnlineGame {
		const game = new OnlineGame(record.seating);
		for (const side of SIDES) {
			const placements = record.setups[side];
			if (placements !== undefined && !game.submitSetup(side, placements).accepted) {
				throw new Error(`The stored Setup of ${side} is not valid`);
			}
		}
		for (const move of record.moves) {
			if (!game.play(game.sideToMove(), move).accepted) {
				throw new Error("A stored Move cannot be replayed");
			}
		}
		const concession = record.concession;
		if (concession !== undefined && !game.concede(concession.loser, concession.reason).accepted) {
			throw new Error("The stored concession cannot be replayed");
		}
		return game;
	}

	toRecord(): GameRecord {
		const setups: Partial<Record<Side, readonly Placement[]>> = {};
		this.setups.forEach(({ placements }, side) => (setups[side] = placements));
		const record: GameRecord = { seating: this.seating, setups, moves: [...this.moves] };
		return this.concession === undefined ? record : { ...record, concession: this.concession };
	}

	sideOfSeatToken(seatToken: string): Side | undefined {
		return SIDES.find((side) => sameSecret(this.seating[side].seatToken, seatToken));
	}

	nicknameOf(side: Side): string {
		return this.seating[side].nickname;
	}

	opponentNicknameOf(side: Side): string {
		return this.seating[opponentOf(side)].nickname;
	}

	phase(): OnlinePhase {
		if (this.game === undefined) {
			return "setup";
		}
		return isOver(this.game.result) ? "over" : "playing";
	}

	hasSetup(side: Side): boolean {
		return this.setups.has(side);
	}

	submitSetup(side: Side, placements: readonly Placement[]): SetupAttempt {
		if (this.hasSetup(side)) {
			return { accepted: false, reason: "setup_already_done" };
		}
		const setup = setupOf(side, placements);
		if (setup === undefined) {
			return { accepted: false, reason: "invalid_setup" };
		}
		this.setups.set(side, { placements, setup });
		this.startWhenBothSetupsAreIn();
		return { accepted: true };
	}

	/** Gives a Random Setup to each side still without a Setup, which starts play. Only during Setup. */
	arrangeMissingSetupsAtRandom(draws: SetupDraws): void {
		if (this.phase() !== "setup") {
			return;
		}
		for (const side of SIDES.filter((missing) => !this.hasSetup(missing))) {
			if (!this.submitSetup(side, placementsOf(Setup.random(side, draws))).accepted) {
				throw new Error(`The Random Setup of ${side} is not valid`);
			}
		}
	}

	play(side: Side, move: Move): OnlineMoveAttempt {
		const game = this.game;
		if (game === undefined) {
			return { accepted: false, reason: "game_not_started" };
		}
		if (isOver(game.result)) {
			return { accepted: false, reason: "game_over" };
		}
		if (game.sideToMove !== side) {
			return { accepted: false, reason: "not_your_turn" };
		}
		const attempt = game.tryPlay(move);
		if (!attempt.accepted) {
			return { accepted: false, reason: "illegal_move" };
		}
		const event = publicMoveEventOf(attempt.record);
		this.moves.push(move);
		this.events.push(event);
		return { accepted: true, event };
	}

	/** Ends the game with Victory to the Opponent of [side], who Resigned or Forfeited. Only during play. */
	concede(side: Side, reason: ConcessionReason): ConcessionAttempt {
		const game = this.game;
		if (game === undefined) {
			return { accepted: false, reason: "game_not_started" };
		}
		if (isOver(game.result)) {
			return { accepted: false, reason: "game_over" };
		}
		game.concede(side, reason);
		this.concession = { loser: side, reason };
		return { accepted: true };
	}

	/** Only once play has started. */
	viewOf(side: Side): PlayerView {
		return playerViewOf(this.startedGame(), side);
	}

	/** What both players learned from every Move so far, in order. */
	history(): readonly PublicMoveEvent[] {
		return [...this.events];
	}

	/** Every Piece left on the Board with its Piece Type, once the game is over; undefined before. */
	finalBoard(): readonly ShownPiece[] | undefined {
		if (this.phase() !== "over") {
			return undefined;
		}
		const board = this.startedGame().board;
		return SIDES.flatMap((side) =>
			board
				.squaresOf(side)
				.toSorted(compareSquares)
				.flatMap((square) => {
					const piece = board.pieceAt(square);
					return piece === undefined ? [] : [{ square, type: piece.type, side }];
				}),
		);
	}

	private sideToMove(): Side {
		return this.startedGame().sideToMove;
	}

	private startedGame(): Game {
		if (this.game === undefined) {
			throw new Error("The game has not started: a Setup is missing");
		}
		return this.game;
	}

	private startWhenBothSetupsAreIn(): void {
		const red = this.setups.get("red");
		const green = this.setups.get("green");
		if (red === undefined || green === undefined) {
			return;
		}
		this.game = gameFromSetups(red.setup, green.setup);
	}
}

/** The Setup [placements] describe, or undefined unless they fill [side]'s rows with exactly its Army, one Piece per Square. */
function setupOf(side: Side, placements: readonly Placement[]): Setup | undefined {
	const setup = new Setup(side);
	const squareCount = Setup.squaresFor(side).length;
	const distinctSquares = placements.filter(
		(placement, index) => placements.findIndex((other) => sameSquare(other.square, placement.square)) === index,
	);
	if (placements.length !== squareCount || distinctSquares.length !== squareCount) {
		return undefined;
	}
	for (const { square, type } of placements) {
		if (!setup.isSetupSquare(square)) {
			return undefined;
		}
		setup.place(square, type);
	}
	return setup.isValid() ? setup : undefined;
}

function placementsOf(setup: Setup): Placement[] {
	return Setup.squaresFor(setup.side).flatMap((square) => {
		const type = setup.typeAt(square);
		return type === undefined ? [] : [{ square, type }];
	});
}

/** Compares in time that does not depend on where the texts first differ, so a Seat Token cannot be guessed by timing. */
function sameSecret(expected: string, given: string): boolean {
	let difference = expected.length ^ given.length;
	for (let index = 0; index < expected.length; index++) {
		difference |= expected.charCodeAt(index) ^ given.charCodeAt(index % Math.max(given.length, 1));
	}
	return difference === 0;
}
