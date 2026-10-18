import type { Move } from "../rules/move";
import { opponentOf, SIDES, type Side } from "../rules/side";
import type { GameRecord, OnlineGame } from "./online-game";
import { parseRefereeRequest, type Placement, type RefereeRefusal, type RefereeReply } from "./protocol";

/** The open sockets of one game and the side each one has taken. */
export interface SeatConnections<Connection> {
	/** The side [connection] took, or undefined before it took a seat. */
	sideOf(connection: Connection): Side | undefined;
	seat(connection: Connection, side: Side): void;
	/** The open sockets seated on [side]. */
	connectionsOf(side: Side): readonly Connection[];
	/** Does nothing when the socket has already closed. */
	send(connection: Connection, reply: RefereeReply): void;
	close(connection: Connection): void;
}

/** Keeps a game's record safe across restarts. */
export interface GameStore {
	save(record: GameRecord): Promise<void>;
}

/**
 * Referees one online game over its sockets: seats each Guest by their Seat
 * Token, takes Setups and Moves from them, saves every change, and sends each
 * player only what their side may know.
 */
export class RefereeSession<Connection> {
	constructor(
		private readonly game: OnlineGame,
		private readonly connections: SeatConnections<Connection>,
		private readonly store: GameStore,
	) {}

	async receive(connection: Connection, text: string): Promise<void> {
		const parse = parseRefereeRequest(text);
		const side = this.connections.sideOf(connection);
		if (!parse.valid) {
			this.refuseMalformed(connection, side);
			return;
		}
		const request = parse.request;
		if (request.type === "take_seat") {
			this.takeSeat(connection, request.seatToken, side);
			return;
		}
		if (side === undefined) {
			this.refuseAndClose(connection, "not_seated");
			return;
		}
		if (request.type === "setup") {
			await this.submitSetup(connection, side, request.placements);
			return;
		}
		await this.play(connection, side, request.move);
	}

	private takeSeat(connection: Connection, seatToken: string, currentSide: Side | undefined): void {
		if (currentSide !== undefined) {
			this.refuse(connection, "already_seated");
			return;
		}
		const side = this.game.sideOfSeatToken(seatToken);
		if (side === undefined) {
			this.refuseAndClose(connection, "unknown_seat");
			return;
		}
		for (const previous of this.connections.connectionsOf(side)) {
			this.refuseAndClose(previous, "seat_taken_elsewhere");
		}
		this.connections.seat(connection, side);
		this.connections.send(connection, { type: "seated", side, opponent: this.game.opponentNicknameOf(side) });
		this.connections.send(connection, this.stateFor(side));
	}

	private async submitSetup(connection: Connection, side: Side, placements: readonly Placement[]): Promise<void> {
		const attempt = this.game.submitSetup(side, placements);
		if (!attempt.accepted) {
			this.refuse(connection, attempt.reason);
			return;
		}
		await this.store.save(this.game.toRecord());
		this.tellBothSides((viewer) => this.stateFor(viewer));
	}

	private async play(connection: Connection, side: Side, move: Move): Promise<void> {
		const attempt = this.game.play(side, move);
		if (!attempt.accepted) {
			this.refuse(connection, attempt.reason);
			return;
		}
		await this.store.save(this.game.toRecord());
		const finalBoard = this.game.finalBoard();
		this.tellBothSides((viewer) => ({
			type: "moved",
			event: attempt.event,
			view: this.game.viewOf(viewer),
			...(finalBoard === undefined ? {} : { finalBoard }),
		}));
	}

	/** Where the game stands for [side]: the Setup progress, or the game so far. */
	private stateFor(side: Side): RefereeReply {
		if (this.game.phase() === "setup") {
			return {
				type: "setup_status",
				ownSetupDone: this.game.hasSetup(side),
				opponentSetupDone: this.game.hasSetup(opponentOf(side)),
			};
		}
		const finalBoard = this.game.finalBoard();
		return {
			type: "game_state",
			view: this.game.viewOf(side),
			history: this.game.history(),
			...(finalBoard === undefined ? {} : { finalBoard }),
		};
	}

	private tellBothSides(replyFor: (viewer: Side) => RefereeReply): void {
		for (const viewer of SIDES) {
			for (const connection of this.connections.connectionsOf(viewer)) {
				this.connections.send(connection, replyFor(viewer));
			}
		}
	}

	/** A seated Guest keeps their socket after a bad message; anyone else is shown out. */
	private refuseMalformed(connection: Connection, side: Side | undefined): void {
		if (side === undefined) {
			this.refuseAndClose(connection, "malformed_message");
		} else {
			this.refuse(connection, "malformed_message");
		}
	}

	private refuse(connection: Connection, reason: RefereeRefusal): void {
		this.connections.send(connection, { type: "refused", reason });
	}

	private refuseAndClose(connection: Connection, reason: RefereeRefusal): void {
		this.refuse(connection, reason);
		this.connections.close(connection);
	}
}
