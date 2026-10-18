import type { Move } from "../rules/move";
import type { SetupDraws } from "../rules/setup";
import { opponentOf, SIDES, type Side } from "../rules/side";
import type { GameRecord, OnlineGame } from "./online-game";
import {
	parseRefereeRequest,
	type Placement,
	type QuickChatMessage,
	type RefereeRefusal,
	type RefereeReply,
} from "./protocol";
import type { RefereeDeadlines } from "./referee-deadlines";
import type { OpenedRematch, RematchMaker } from "./rematch-maker";

/** The open sockets of one game and the side each one has taken. */
export interface SeatConnections<Connection> {
	/** The side [connection] took, or undefined before it took a seat. */
	sideOf(connection: Connection): Side | undefined;
	seat(connection: Connection, side: Side): void;
	/** The open sockets seated on [side]. */
	connectionsOf(side: Side): readonly Connection[];
	/** Does nothing when the socket has already closed. */
	send(connection: Connection, reply: RefereeReply): void;
	/** Closes the socket with [reason] in the close frame. */
	refuseAndClose(connection: Connection, reason: RefereeRefusal): void;
	/** Remembers on [connection] that its player asks for a Rematch. */
	markWantsRematch(connection: Connection): void;
	/** True when an open socket of [side] asks for a Rematch. */
	wantsRematch(side: Side): boolean;
}

/** Keeps a game's record safe across restarts. */
export interface GameStore {
	save(record: GameRecord): Promise<void>;
}

/**
 * Referees one online game over its sockets: seats each Guest by their Seat
 * Token, takes Setups, Moves and resignations from them, tells each player
 * when their Opponent leaves or comes back, Forfeits one who stays away too
 * long, saves every change, and sends each player only what their side may
 * know. Relays Quick Chats, and opens a Rematch once both players ask for one.
 */
export class RefereeSession<Connection> {
	constructor(
		private readonly game: OnlineGame,
		private readonly connections: SeatConnections<Connection>,
		private readonly store: GameStore,
		private readonly deadlines: RefereeDeadlines,
		private readonly draws: SetupDraws,
		private readonly rematchMaker: RematchMaker,
	) {}

	/** The Rematch already opened from this game, kept to answer a repeated request. */
	private rematch: OpenedRematch | undefined;

	async receive(connection: Connection, text: string): Promise<void> {
		const parse = parseRefereeRequest(text);
		const side = this.connections.sideOf(connection);
		if (!parse.valid) {
			this.refuseMalformed(connection, side);
			return;
		}
		const request = parse.request;
		if (request.type === "take_seat") {
			await this.takeSeat(connection, request.seatToken, side);
			return;
		}
		if (side === undefined) {
			this.refuseAndClose(connection, "not_seated");
			return;
		}
		switch (request.type) {
			case "setup":
				await this.submitSetup(connection, side, request.placements);
				return;
			case "move":
				await this.play(connection, side, request.move);
				return;
			case "resign":
				await this.resign(connection, side);
				return;
			case "quick_chat":
				this.relayQuickChat(side, request.message);
				return;
			case "rematch":
				await this.askForRematch(connection, side);
				return;
		}
	}

	/** [connection] has closed. When it was its side's last socket, that player is now away. */
	async disconnect(connection: Connection): Promise<void> {
		const side = this.connections.sideOf(connection);
		if (side === undefined || this.connections.connectionsOf(side).some((other) => other !== connection)) {
			return;
		}
		await this.deadlines.forfeitWatch.left(side);
		this.tellOpponentOf(side, { type: "opponent_presence", connected: false });
		await this.scheduleAlarm();
	}

	/**
	 * Ends Setup if the Setup Timer has run out, then Forfeits the player who
	 * has stayed away too long, if anyone has, and sets the alarm again.
	 */
	async alarmRang(): Promise<void> {
		if (this.game.phase() === "setup" && this.deadlines.setupTimer.isUp()) {
			this.game.arrangeMissingSetupsAtRandom(this.draws);
			await this.store.save(this.game.toRecord());
			this.tellBothSides((viewer) => this.stateFor(viewer));
		}
		const absent = this.deadlines.forfeitWatch.overdue();
		if (absent !== undefined && this.game.concede(absent, "forfeited").accepted) {
			await this.endByConcession();
			return;
		}
		await this.scheduleAlarm();
	}

	/**
	 * Sets the alarm for the next deadline: the Setup Timer during Setup, the
	 * first Forfeit during play, none once the game is over. Called when a game
	 * opens; the session keeps it set after that.
	 */
	async scheduleAlarm(): Promise<void> {
		await this.deadlines.alarm.setFor(this.nextDeadline());
	}

	private async takeSeat(connection: Connection, seatToken: string, currentSide: Side | undefined): Promise<void> {
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
		await this.comeBack(connection, side);
	}

	/** Tells the Opponent that [side] is back, and [connection] whether the Opponent is away. */
	private async comeBack(connection: Connection, side: Side): Promise<void> {
		if (this.deadlines.forfeitWatch.isAway(side)) {
			await this.deadlines.forfeitWatch.returned(side);
			this.tellOpponentOf(side, { type: "opponent_presence", connected: true });
			await this.scheduleAlarm();
		}
		if (this.deadlines.forfeitWatch.isAway(opponentOf(side))) {
			this.connections.send(connection, { type: "opponent_presence", connected: false });
		}
	}

	private async submitSetup(connection: Connection, side: Side, placements: readonly Placement[]): Promise<void> {
		const attempt = this.game.submitSetup(side, placements);
		if (!attempt.accepted) {
			this.refuse(connection, attempt.reason);
			return;
		}
		await this.store.save(this.game.toRecord());
		this.tellBothSides((viewer) => this.stateFor(viewer));
		await this.scheduleAlarm();
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
		if (finalBoard !== undefined) {
			await this.scheduleAlarm();
		}
	}

	private async resign(connection: Connection, side: Side): Promise<void> {
		const attempt = this.game.concede(side, "resigned");
		if (!attempt.accepted) {
			this.refuse(connection, attempt.reason);
			return;
		}
		await this.endByConcession();
	}

	private relayQuickChat(side: Side, message: QuickChatMessage): void {
		this.tellBothSides(() => ({ type: "quick_chat", side, message }));
	}

	/** Opens the Rematch once both players asked, sides swapped; until then, tells the Opponent. */
	private async askForRematch(connection: Connection, side: Side): Promise<void> {
		if (this.game.phase() !== "over") {
			this.refuse(connection, "game_not_over");
			return;
		}
		if (this.rematch !== undefined) {
			this.connections.send(connection, this.rematchSeat(this.rematch, opponentOf(side)));
			return;
		}
		this.connections.markWantsRematch(connection);
		if (!this.connections.wantsRematch(opponentOf(side))) {
			this.tellOpponentOf(side, { type: "rematch_offered" });
			return;
		}
		try {
			this.rematch = await this.rematchMaker.open({
				red: this.game.nicknameOf("green"),
				green: this.game.nicknameOf("red"),
			});
		} catch {
			this.tellBothSides(() => ({ type: "refused", reason: "rematch_unavailable" }));
			return;
		}
		const opened = this.rematch;
		this.tellBothSides((viewer) => this.rematchSeat(opened, opponentOf(viewer)));
	}

	/** The seat in [rematch] of the player who sat on [newSide]. */
	private rematchSeat(rematch: OpenedRematch, newSide: Side): RefereeReply {
		return {
			type: "rematch_ready",
			gameId: rematch.gameId,
			side: newSide,
			seatToken: rematch.seating[newSide].seatToken,
			opponent: rematch.seating[opponentOf(newSide)].nickname,
		};
	}

	private async endByConcession(): Promise<void> {
		await this.store.save(this.game.toRecord());
		this.tellBothSides((viewer) => this.stateFor(viewer));
		await this.scheduleAlarm();
	}

	private nextDeadline(): number | undefined {
		switch (this.game.phase()) {
			case "setup":
				return this.deadlines.setupTimer.deadline;
			case "playing":
				return this.deadlines.forfeitWatch.firstDeadline();
			case "over":
				return undefined;
		}
	}

	/** Where the game stands for [side]: the Setup progress, or the game so far. */
	private stateFor(side: Side): RefereeReply {
		if (this.game.phase() === "setup") {
			return {
				type: "setup_status",
				ownSetupDone: this.game.hasSetup(side),
				opponentSetupDone: this.game.hasSetup(opponentOf(side)),
				setupTimeLeftMs: this.deadlines.setupTimer.timeLeftMs(),
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

	private tellOpponentOf(side: Side, reply: RefereeReply): void {
		for (const connection of this.connections.connectionsOf(opponentOf(side))) {
			this.connections.send(connection, reply);
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
		this.connections.refuseAndClose(connection, reason);
	}
}
