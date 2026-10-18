import { opponentOf, type Side } from "../rules/side";
import type { Seating } from "../referee/seating";
import { parseQuickMatchRequest, type QuickMatchReply, type RefusalReason } from "./protocol";

/** A Guest who joined Quick Match and has no Opponent yet. */
export interface WaitingGuest<Connection> {
	readonly connection: Connection;
	readonly nickname: string;
}

/** The open Quick Match sockets and what each Guest has done so far. */
export interface GuestConnections<Connection> {
	/** Guests still connected and waiting, the longest waiting first. */
	waitingGuests(): readonly WaitingGuest<Connection>[];
	hasJoined(connection: Connection): boolean;
	markWaiting(connection: Connection, nickname: string): void;
	markPaired(connection: Connection): void;
	/** Does nothing when the socket has already closed. */
	send(connection: Connection, reply: QuickMatchReply): void;
	close(connection: Connection): void;
}

/** Creates the referee of a new game. */
export interface GameOpener {
	/** Resolves with the new game's id; rejects when no game could be opened. */
	open(seating: Seating): Promise<string>;
}

/** The chance in a pairing. */
export interface PairingDraws {
	/** An unguessable secret, new on every call. */
	seatToken(): string;
	newcomerPlaysRed(): boolean;
}

/**
 * Pairs each Guest who joins Quick Match with the Guest who has waited
 * longest, draws lots for the sides and opens their game.
 */
export class QuickMatchPairer<Connection> {
	constructor(
		private readonly connections: GuestConnections<Connection>,
		private readonly opener: GameOpener,
		private readonly draws: PairingDraws,
	) {}

	async receive(connection: Connection, text: string): Promise<void> {
		if (this.connections.hasJoined(connection)) {
			this.connections.send(connection, { type: "refused", reason: "already_joined" });
			return;
		}
		const parse = parseQuickMatchRequest(text);
		if (!parse.valid) {
			this.refuse([connection], parse.reason);
			return;
		}
		const newcomer = { connection, nickname: parse.request.nickname };
		const opponent = this.connections.waitingGuests()[0];
		if (opponent === undefined) {
			this.connections.markWaiting(connection, newcomer.nickname);
			this.connections.send(connection, { type: "waiting" });
			return;
		}
		await this.pair(newcomer, opponent);
	}

	/** Takes both Guests out of the waiting list before any await, so no one else can claim them meanwhile. */
	private async pair(newcomer: WaitingGuest<Connection>, opponent: WaitingGuest<Connection>): Promise<void> {
		this.connections.markPaired(newcomer.connection);
		this.connections.markPaired(opponent.connection);
		const [red, green] = this.draws.newcomerPlaysRed() ? [newcomer, opponent] : [opponent, newcomer];
		const seating: Seating = {
			red: { nickname: red.nickname, seatToken: this.draws.seatToken() },
			green: { nickname: green.nickname, seatToken: this.draws.seatToken() },
		};
		let gameId: string;
		try {
			gameId = await this.opener.open(seating);
		} catch {
			this.refuse([red.connection, green.connection], "game_unavailable");
			return;
		}
		this.seat(red.connection, "red", gameId, seating);
		this.seat(green.connection, "green", gameId, seating);
	}

	private seat(connection: Connection, side: Side, gameId: string, seating: Seating): void {
		this.connections.send(connection, {
			type: "paired",
			gameId,
			side,
			seatToken: seating[side].seatToken,
			opponent: seating[opponentOf(side)].nickname,
		});
		this.connections.close(connection);
	}

	private refuse(connections: readonly Connection[], reason: RefusalReason): void {
		for (const connection of connections) {
			this.connections.send(connection, { type: "refused", reason });
			this.connections.close(connection);
		}
	}
}
