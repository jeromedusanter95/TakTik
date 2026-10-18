import type { Side } from "../rules/side";
import { parseJsonObject } from "../wire/json-object";

/**
 * The messages of the Lobby WebSocket. A Guest first enters with a nickname,
 * then sees the other Guests and either waits for a Quick Match or sends a
 * Challenge to one of them. Once paired, the server says where to play and the
 * Guest closes the socket. A Guest the server shows out gets the refusal both
 * as a message and as the close reason.
 */
export type LobbyRequest =
	/** [inGame] enters a Guest who is playing an online game, listed but out of reach. */
	| { readonly type: "enter"; readonly nickname: string; readonly inGame: boolean }
	| { readonly type: "quick_match" }
	| { readonly type: "stop_waiting" }
	| { readonly type: "challenge"; readonly guestId: string }
	| { readonly type: "withdraw_challenge" }
	| { readonly type: "answer_challenge"; readonly guestId: string; readonly accept: boolean };

/** Another Guest as the Lobby lists them. */
export interface ListedGuest {
	readonly guestId: string;
	readonly nickname: string;
	/** True while they wait for a Quick Match. */
	readonly waiting: boolean;
	/** True while they play an online game: they can be seen but not challenged. */
	readonly inGame: boolean;
}

/**
 * Why a Challenge stopped: its Guest declined, its sender withdrew it, one of
 * them left the Lobby, or its Guest is playing a game.
 */
export type ChallengeEnd = "declined" | "withdrawn" | "gone" | "busy";

export type LobbyReply =
	| { readonly type: "entered"; readonly guestId: string }
	/** The other Guests in the Lobby, the longest there first. Sent whenever it changes. */
	| { readonly type: "guests"; readonly guests: readonly ListedGuest[] }
	/** Whether this Guest now waits for a Quick Match. */
	| { readonly type: "quick_match"; readonly waiting: boolean }
	| { readonly type: "challenge_sent"; readonly guestId: string }
	| { readonly type: "challenged"; readonly guestId: string; readonly nickname: string }
	/** The Challenge between this Guest and [guestId], either way, is over. */
	| { readonly type: "challenge_ended"; readonly guestId: string; readonly reason: ChallengeEnd }
	| {
			readonly type: "paired";
			readonly gameId: string;
			readonly side: Side;
			/** The secret that proves to the referee this Guest owns this seat. */
			readonly seatToken: string;
			readonly opponent: string;
	  }
	| { readonly type: "refused"; readonly reason: LobbyRefusal };

export type LobbyRefusal =
	| "malformed_message"
	| "invalid_nickname"
	| "already_entered"
	| "not_entered"
	| "unknown_guest"
	| "no_such_challenge"
	| "game_unavailable"
	| "in_game";

export type LobbyRequestParse =
	| { readonly valid: true; readonly request: LobbyRequest }
	| { readonly valid: false; readonly reason: LobbyRefusal };

/** Counted in characters, not UTF-16 code units, after trimming. */
export const MAX_NICKNAME_LENGTH = 16;

/** Guest ids are short hex strings; this only bounds what is worth looking up. */
const MAX_GUEST_ID_LENGTH = 32;

/** Control and invisible format characters, which could fake or hide a nickname. */
const UNPRINTABLE = /[\p{Cc}\p{Cf}]/u;

const MALFORMED: LobbyRequestParse = { valid: false, reason: "malformed_message" };

export function parseLobbyRequest(text: string): LobbyRequestParse {
	const message = parseJsonObject(text);
	switch (message?.["type"]) {
		case "enter":
			return enterFrom(message["nickname"], message["inGame"]);
		case "quick_match":
			return accepted({ type: "quick_match" });
		case "stop_waiting":
			return accepted({ type: "stop_waiting" });
		case "challenge":
			return challengeFrom(message["guestId"]);
		case "withdraw_challenge":
			return accepted({ type: "withdraw_challenge" });
		case "answer_challenge":
			return answerFrom(message["guestId"], message["accept"]);
		default:
			return MALFORMED;
	}
}

export function formatLobbyReply(reply: LobbyReply): string {
	return JSON.stringify(reply);
}

function accepted(request: LobbyRequest): LobbyRequestParse {
	return { valid: true, request };
}

function enterFrom(value: unknown, inGameValue: unknown): LobbyRequestParse {
	const nickname = nicknameFrom(value);
	if (nickname === undefined) {
		return { valid: false, reason: "invalid_nickname" };
	}
	if (inGameValue !== undefined && typeof inGameValue !== "boolean") {
		return MALFORMED;
	}
	return accepted({ type: "enter", nickname, inGame: inGameValue === true });
}

function challengeFrom(value: unknown): LobbyRequestParse {
	const guestId = guestIdFrom(value);
	return guestId === undefined ? MALFORMED : accepted({ type: "challenge", guestId });
}

function answerFrom(guestValue: unknown, acceptValue: unknown): LobbyRequestParse {
	const guestId = guestIdFrom(guestValue);
	if (guestId === undefined || typeof acceptValue !== "boolean") {
		return MALFORMED;
	}
	return accepted({ type: "answer_challenge", guestId, accept: acceptValue });
}

function guestIdFrom(value: unknown): string | undefined {
	return typeof value === "string" && value.length > 0 && value.length <= MAX_GUEST_ID_LENGTH ? value : undefined;
}

function nicknameFrom(value: unknown): string | undefined {
	if (typeof value !== "string") {
		return undefined;
	}
	const nickname = value.trim();
	const length = [...nickname].length;
	if (length === 0 || length > MAX_NICKNAME_LENGTH || UNPRINTABLE.test(nickname)) {
		return undefined;
	}
	return nickname;
}
