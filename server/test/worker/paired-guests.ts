import type { LobbyReply } from "../../src/lobby/protocol";
import type { RefereeReply } from "../../src/referee/protocol";
import type { Side } from "../../src/rules/side";
import { JsonSocket, socketUrl } from "./json-socket";

export type PlayerSocket = JsonSocket<RefereeReply>;

export interface PairedSeat {
	readonly gameId: string;
	readonly seatToken: string;
	readonly opponent: string;
}

/** Pairs two Guests through Quick Match in the Lobby on the server at [base] and returns each side's seat. */
export async function pairTwoGuests(base: URL): Promise<Record<Side, PairedSeat>> {
	const guests: JsonSocket<LobbyReply>[] = [];
	for (const nickname of ["Ada", "Bob"]) {
		const guest = await JsonSocket.open<LobbyReply>(socketUrl(base, "/lobby"));
		guest.send({ type: "enter", nickname });
		guest.send({ type: "quick_match" });
		await guest.replyWhere((reply) => reply.type === "entered");
		guests.push(guest);
	}
	const seats: Partial<Record<Side, PairedSeat>> = {};
	for (const guest of guests) {
		const paired = await guest.replyWhere((reply) => reply.type === "paired" || reply.type === "refused");
		guest.leave();
		if (paired?.type !== "paired") {
			throw new Error(`a Guest was not paired: ${JSON.stringify(guest.replies)}`);
		}
		seats[paired.side] = { gameId: paired.gameId, seatToken: paired.seatToken, opponent: paired.opponent };
	}
	const { red, green } = seats;
	if (red === undefined || green === undefined) {
		throw new Error("both sides should be seated");
	}
	return { red, green };
}

/** Opens a socket on [seat]'s game and takes the seat, once the referee has answered with where the game stands. */
export async function takeSeat(base: URL, seat: PairedSeat): Promise<PlayerSocket> {
	const player = await JsonSocket.open<RefereeReply>(socketUrl(base, `/games/${seat.gameId}`));
	player.send({ type: "take_seat", seatToken: seat.seatToken });
	await player.replyCount(2);
	return player;
}
