import type { Side } from "../rules/side";
import { parseJsonObject } from "../wire/json-object";

/**
 * The messages of the Quick Match WebSocket. A Guest sends one join; the
 * server answers waiting, then paired once an Opponent turns up, and closes the
 * socket. A refused join also closes it.
 */
export type QuickMatchRequest = { readonly type: "join"; readonly nickname: string };

export type QuickMatchReply =
	| { readonly type: "waiting" }
	| {
			readonly type: "paired";
			readonly gameId: string;
			readonly side: Side;
			/** The secret that proves to the referee this Guest owns this seat. */
			readonly seatToken: string;
			readonly opponent: string;
	  }
	| { readonly type: "refused"; readonly reason: RefusalReason };

export type RefusalReason = "malformed_message" | "invalid_nickname" | "already_joined" | "game_unavailable";

export type RequestParse =
	| { readonly valid: true; readonly request: QuickMatchRequest }
	| { readonly valid: false; readonly reason: RefusalReason };

/** Counted in characters, not UTF-16 code units, after trimming. */
export const MAX_NICKNAME_LENGTH = 16;

/** Control and invisible format characters, which could fake or hide a nickname. */
const UNPRINTABLE = /[\p{Cc}\p{Cf}]/u;

export function parseQuickMatchRequest(text: string): RequestParse {
	const message = parseJsonObject(text);
	if (message === undefined || message["type"] !== "join") {
		return { valid: false, reason: "malformed_message" };
	}
	const nickname = nicknameFrom(message["nickname"]);
	if (nickname === undefined) {
		return { valid: false, reason: "invalid_nickname" };
	}
	return { valid: true, request: { type: "join", nickname } };
}

export function formatQuickMatchReply(reply: QuickMatchReply): string {
	return JSON.stringify(reply);
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
