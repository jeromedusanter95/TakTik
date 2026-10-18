import type { Seating } from "../referee/seating";
import { opponentOf, type Side } from "../rules/side";
import type { GameOpener } from "./game-opener";
import {
	parseLobbyRequest,
	type ChallengeEnd,
	type LobbyRefusal,
	type LobbyReply,
	type ListedGuest,
} from "./protocol";

/** What the Lobby remembers about a Guest who entered and is not paired yet. */
export interface GuestState {
	readonly guestId: string;
	readonly nickname: string;
	/** When they entered, to list Guests and serve Quick Match in order. */
	readonly enteredAt: number;
	/** True while they wait for a Quick Match. */
	readonly waiting: boolean;
	/** The Guest they sent a Challenge to, if any. */
	readonly challenging?: string;
}

/** A change to a Guest's state; [challenging] undefined ends their Challenge. */
interface GuestChange {
	readonly waiting?: boolean;
	readonly challenging?: string | undefined;
}

export interface LobbyGuest<Connection> extends GuestState {
	readonly connection: Connection;
}

/** The open Lobby sockets and what each Guest has done so far. */
export interface LobbyConnections<Connection> {
	/** Guests in the Lobby: entered, still connected and not paired, the longest there first. */
	guests(): readonly LobbyGuest<Connection>[];
	/** The Lobby state of [connection]'s Guest, even after its socket closed; undefined before entering and once paired. */
	stateOf(connection: Connection): GuestState | undefined;
	/** True once [connection] entered, paired or not. */
	hasEntered(connection: Connection): boolean;
	setState(connection: Connection, state: GuestState): void;
	markPaired(connection: Connection): void;
	/** Does nothing when the socket has already closed. */
	send(connection: Connection, reply: LobbyReply): void;
	/** Closes the socket with [reason] in the close frame. */
	refuseAndClose(connection: Connection, reason: LobbyRefusal): void;
}

/** The chance in the Lobby. */
export interface LobbyDraws {
	/** A new id for a Guest, unique in the Lobby. Not a secret. */
	guestId(): string;
	/** An unguessable secret, new on every call. */
	seatToken(): string;
	/** Whether the first Guest of a pairing plays Red. */
	firstPlaysRed(): boolean;
}

export interface Clock {
	now(): number;
}

/** How many other Guests a Lobby listing shows at most, the longest there first. */
export const MAX_LISTED_GUESTS = 50;

/**
 * The place where Guests find an Opponent: through Quick Match with whoever
 * has waited longest, or by Challenging a Guest, who accepts or declines.
 * Pairs two Guests by drawing lots for the sides and opening their game; each
 * paired Guest then closes their own socket.
 */
export class Lobby<Connection> {
	constructor(
		private readonly connections: LobbyConnections<Connection>,
		private readonly opener: GameOpener,
		private readonly draws: LobbyDraws,
		private readonly clock: Clock,
	) {}

	async receive(connection: Connection, text: string): Promise<void> {
		const parse = parseLobbyRequest(text);
		const entered = this.connections.hasEntered(connection);
		if (!parse.valid) {
			this.refuseInvalid(connection, parse.reason, entered);
			return;
		}
		const request = parse.request;
		if (request.type === "enter") {
			this.enter(connection, request.nickname, entered);
			return;
		}
		if (!entered) {
			this.connections.refuseAndClose(connection, "not_entered");
			return;
		}
		const guest = this.guestOn(connection);
		if (guest === undefined) {
			return;
		}
		switch (request.type) {
			case "quick_match":
				await this.joinQuickMatch(guest);
				return;
			case "stop_waiting":
				this.stopWaiting(guest);
				return;
			case "challenge":
				this.challenge(guest, request.guestId);
				return;
			case "withdraw_challenge":
				this.endChallengeOf(guest, "withdrawn");
				this.listGuests();
				return;
			case "answer_challenge":
				await this.answer(guest, request.guestId, request.accept);
				return;
		}
	}

	/** Called when [connection]'s socket has closed: ends the Challenges it took part in. */
	leave(connection: Connection): void {
		const state = this.connections.stateOf(connection);
		if (state === undefined) {
			return;
		}
		this.tellChallengeEnded(state.challenging, state.guestId, "gone");
		this.dropChallengesTo([state.guestId]);
		this.listGuests();
	}

	private refuseInvalid(connection: Connection, reason: LobbyRefusal, entered: boolean): void {
		if (entered && reason === "malformed_message") {
			this.connections.send(connection, { type: "refused", reason });
			return;
		}
		this.connections.send(connection, { type: "refused", reason });
		this.connections.refuseAndClose(connection, reason);
	}

	private enter(connection: Connection, nickname: string, entered: boolean): void {
		if (entered) {
			this.connections.send(connection, { type: "refused", reason: "already_entered" });
			return;
		}
		const guestId = this.draws.guestId();
		this.connections.setState(connection, { guestId, nickname, enteredAt: this.clock.now(), waiting: false });
		this.connections.send(connection, { type: "entered", guestId });
		this.listGuests();
	}

	private async joinQuickMatch(guest: LobbyGuest<Connection>): Promise<void> {
		this.endChallengeOf(guest, "withdrawn");
		const opponent = this.guests().find((other) => other.waiting && other.connection !== guest.connection);
		if (opponent !== undefined) {
			await this.pair(opponent, this.refreshed(guest));
			return;
		}
		this.update(guest, { waiting: true });
		this.connections.send(guest.connection, { type: "quick_match", waiting: true });
		this.listGuests();
	}

	private stopWaiting(guest: LobbyGuest<Connection>): void {
		this.update(guest, { waiting: false });
		this.connections.send(guest.connection, { type: "quick_match", waiting: false });
		this.listGuests();
	}

	private challenge(sender: LobbyGuest<Connection>, targetId: string): void {
		const target = this.guests().find((other) => other.guestId === targetId && other.connection !== sender.connection);
		if (target === undefined) {
			this.connections.send(sender.connection, { type: "refused", reason: "unknown_guest" });
			return;
		}
		if (sender.challenging !== targetId) {
			this.endChallengeOf(sender, "withdrawn");
		}
		this.update(this.refreshed(sender), { waiting: false, challenging: targetId });
		this.connections.send(sender.connection, { type: "challenge_sent", guestId: targetId });
		this.connections.send(target.connection, { type: "challenged", guestId: sender.guestId, nickname: sender.nickname });
		this.listGuests();
	}

	private async answer(guest: LobbyGuest<Connection>, senderId: string, accept: boolean): Promise<void> {
		const sender = this.guests().find((other) => other.guestId === senderId && other.challenging === guest.guestId);
		if (sender === undefined) {
			this.connections.send(guest.connection, { type: "refused", reason: "no_such_challenge" });
			return;
		}
		if (accept) {
			await this.pair(sender, guest);
			return;
		}
		this.endChallengeOf(sender, "declined");
	}

	/**
	 * Takes both Guests out of the Lobby before any await, so no one else can
	 * claim them meanwhile, and ends every other Challenge they took part in.
	 */
	private async pair(first: LobbyGuest<Connection>, second: LobbyGuest<Connection>): Promise<void> {
		this.connections.markPaired(first.connection);
		this.connections.markPaired(second.connection);
		for (const guest of [first, second]) {
			const partner = guest === first ? second : first;
			if (guest.challenging !== partner.guestId) {
				this.tellChallengeEnded(guest.challenging, guest.guestId, "gone");
			}
		}
		this.dropChallengesTo([first.guestId, second.guestId]);
		this.listGuests();
		const [red, green] = this.draws.firstPlaysRed() ? [first, second] : [second, first];
		const seating: Seating = {
			red: { nickname: red.nickname, seatToken: this.draws.seatToken() },
			green: { nickname: green.nickname, seatToken: this.draws.seatToken() },
		};
		let gameId: string;
		try {
			gameId = await this.opener.open(seating);
		} catch {
			for (const connection of [red.connection, green.connection]) {
				this.connections.send(connection, { type: "refused", reason: "game_unavailable" });
				this.connections.refuseAndClose(connection, "game_unavailable");
			}
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
	}

	/** Ends the Challenge [sender] sent, if any, telling both Guests. */
	private endChallengeOf(sender: LobbyGuest<Connection>, reason: ChallengeEnd): void {
		const current = this.refreshed(sender);
		if (current.challenging === undefined) {
			return;
		}
		this.connections.send(current.connection, { type: "challenge_ended", guestId: current.challenging, reason });
		this.tellChallengeEnded(current.challenging, current.guestId, reason);
		this.update(current, { challenging: undefined });
	}

	/** Tells the Guest [targetId] that the Challenge from [senderId] is over. */
	private tellChallengeEnded(targetId: string | undefined, senderId: string, reason: ChallengeEnd): void {
		const target = this.guests().find((other) => other.guestId === targetId);
		if (target !== undefined) {
			this.connections.send(target.connection, { type: "challenge_ended", guestId: senderId, reason });
		}
	}

	/** Ends every Challenge sent to one of [goneIds], who left the Lobby. */
	private dropChallengesTo(goneIds: readonly string[]): void {
		for (const sender of this.guests()) {
			if (sender.challenging !== undefined && goneIds.includes(sender.challenging)) {
				this.connections.send(sender.connection, { type: "challenge_ended", guestId: sender.challenging, reason: "gone" });
				this.update(sender, { challenging: undefined });
			}
		}
	}

	/** Sends every Guest the others in the Lobby. */
	private listGuests(): void {
		const guests = this.guests();
		for (const viewer of guests) {
			const others: ListedGuest[] = guests
				.filter((other) => other.connection !== viewer.connection)
				.slice(0, MAX_LISTED_GUESTS)
				.map(({ guestId, nickname, waiting }) => ({ guestId, nickname, waiting }));
			this.connections.send(viewer.connection, { type: "guests", guests: others });
		}
	}

	private guests(): readonly LobbyGuest<Connection>[] {
		return this.connections.guests();
	}

	private guestOn(connection: Connection): LobbyGuest<Connection> | undefined {
		return this.guests().find((guest) => guest.connection === connection);
	}

	/** [guest] as the Lobby holds it now, after any change made since it was read. */
	private refreshed(guest: LobbyGuest<Connection>): LobbyGuest<Connection> {
		return this.guestOn(guest.connection) ?? guest;
	}

	private update(guest: LobbyGuest<Connection>, change: GuestChange): void {
		const { guestId, nickname, enteredAt, waiting, challenging } = this.refreshed(guest);
		const next = { guestId, nickname, enteredAt, waiting: change.waiting ?? waiting };
		const challenge = "challenging" in change ? change.challenging : challenging;
		this.connections.setState(guest.connection, challenge === undefined ? next : { ...next, challenging: challenge });
	}
}
