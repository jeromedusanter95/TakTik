import { Board } from "../rules/board";
import type { Move } from "../rules/move";
import { PIECE_TYPES, type PieceType } from "../rules/piece-type";
import type { Side } from "../rules/side";
import { squareAt, type Square } from "../rules/square";
import type { PlayerView } from "../view/player-view";
import type { PublicMoveEvent } from "../view/public-move-event";
import { asObject, parseJsonObject } from "../wire/json-object";

/**
 * The messages of a game's WebSocket. A Guest first takes their seat with the
 * Seat Token the Lobby gave them, then sends their Setup and their Moves, and
 * may Resign at any point of play. Either player may send a Quick Chat at any
 * time and ask for a Rematch once the game is over.
 * Squares are { column, row } with column 0 as "a" and row 0 as rank 1.
 */
export type RefereeRequest =
	| { readonly type: "take_seat"; readonly seatToken: string }
	| { readonly type: "setup"; readonly placements: readonly Placement[] }
	| { readonly type: "move"; readonly move: Move }
	| { readonly type: "resign" }
	| { readonly type: "quick_chat"; readonly message: QuickChatMessage }
	| { readonly type: "rematch" };

/** The fixed set of messages a player can send during an online game. */
export const QUICK_CHAT_MESSAGES = ["hello", "good_luck", "well_played", "thanks", "oops", "good_game"] as const;

export type QuickChatMessage = (typeof QUICK_CHAT_MESSAGES)[number];

/** One Piece of a Setup. */
export interface Placement {
	readonly square: Square;
	readonly type: PieceType;
}

/** A Piece on the Board with its Piece Type shown, for the Reveal at the end of a game. */
export interface ShownPiece {
	readonly square: Square;
	readonly type: PieceType;
	readonly side: Side;
}

export type RefereeReply =
	| { readonly type: "seated"; readonly side: Side; readonly opponent: string }
	/**
	 * Sent during Setup: on taking a seat, and whenever either player finishes.
	 * [setupTimeLeftMs] is how long the Setup Timer still runs, counted when sent.
	 */
	| {
			readonly type: "setup_status";
			readonly ownSetupDone: boolean;
			readonly opponentSetupDone: boolean;
			readonly setupTimeLeftMs: number;
	  }
	/**
	 * Sent when play starts, whether both Setups are in or the Setup Timer ran
	 * out, and on taking a seat after that. [history] is every Move so far.
	 */
	| {
			readonly type: "game_state";
			readonly view: PlayerView;
			readonly history: readonly PublicMoveEvent[];
			/** While play goes on: how long the player to move still has, counted when sent. */
			readonly turnTimeLeftMs?: number;
			readonly finalBoard?: readonly ShownPiece[];
	  }
	/** Sent to both players after every Move. */
	| {
			readonly type: "moved";
			readonly event: PublicMoveEvent;
			readonly view: PlayerView;
			/** While play goes on: how long the player to move still has, counted when sent. */
			readonly turnTimeLeftMs?: number;
			readonly finalBoard?: readonly ShownPiece[];
	  }
	/**
	 * Sent when the Opponent's last socket closes and when they take their seat
	 * again, and on taking a seat while the Opponent is away.
	 */
	| { readonly type: "opponent_presence"; readonly connected: boolean }
	/** A Quick Chat [side] sent, relayed to both players. */
	| { readonly type: "quick_chat"; readonly side: Side; readonly message: QuickChatMessage }
	/** The Opponent asks for a Rematch. */
	| { readonly type: "rematch_offered" }
	/** Both players asked for a Rematch: the seat in the new game, sides swapped. */
	| {
			readonly type: "rematch_ready";
			readonly gameId: string;
			readonly side: Side;
			readonly seatToken: string;
			readonly opponent: string;
	  }
	| { readonly type: "refused"; readonly reason: RefereeRefusal };

export type RefereeRefusal =
	| "malformed_message"
	| "unknown_seat"
	| "not_seated"
	| "already_seated"
	| "seat_taken_elsewhere"
	| "invalid_setup"
	| "setup_already_done"
	| "game_not_started"
	| "game_over"
	| "not_your_turn"
	| "illegal_move"
	| "game_not_over"
	| "rematch_unavailable";

export type RefereeRequestParse = { readonly valid: true; readonly request: RefereeRequest } | { readonly valid: false };

/** Seat Tokens are 64 hex characters; this only bounds what is worth comparing. */
const MAX_SEAT_TOKEN_LENGTH = 128;

const MALFORMED: RefereeRequestParse = { valid: false };

export function parseRefereeRequest(text: string): RefereeRequestParse {
	const message = parseJsonObject(text);
	const request = message === undefined ? undefined : requestFrom(message);
	return request === undefined ? MALFORMED : { valid: true, request };
}

export function formatRefereeReply(reply: RefereeReply): string {
	return JSON.stringify(reply);
}

function requestFrom(message: Record<string, unknown>): RefereeRequest | undefined {
	switch (message["type"]) {
		case "take_seat":
			return takeSeatFrom(message["seatToken"]);
		case "setup":
			return setupFrom(message["placements"]);
		case "move":
			return moveRequestFrom(message["move"]);
		case "resign":
			return { type: "resign" };
		case "quick_chat":
			return quickChatFrom(message["message"]);
		case "rematch":
			return { type: "rematch" };
		default:
			return undefined;
	}
}

function takeSeatFrom(value: unknown): RefereeRequest | undefined {
	if (typeof value !== "string" || value.length === 0 || value.length > MAX_SEAT_TOKEN_LENGTH) {
		return undefined;
	}
	return { type: "take_seat", seatToken: value };
}

function quickChatFrom(value: unknown): RefereeRequest | undefined {
	const message = QUICK_CHAT_MESSAGES.find((known) => known === value);
	return message === undefined ? undefined : { type: "quick_chat", message };
}

function setupFrom(value: unknown): RefereeRequest | undefined {
	if (!Array.isArray(value)) {
		return undefined;
	}
	const placements = value.map(placementFrom);
	if (!placements.every((placement) => placement !== undefined)) {
		return undefined;
	}
	return { type: "setup", placements };
}

function placementFrom(value: unknown): Placement | undefined {
	const placement = asObject(value);
	const square = squareFrom(placement?.["square"]);
	const type = pieceTypeFrom(placement?.["type"]);
	return square === undefined || type === undefined ? undefined : { square, type };
}

function moveRequestFrom(value: unknown): RefereeRequest | undefined {
	const move = asObject(value);
	const from = squareFrom(move?.["from"]);
	const to = squareFrom(move?.["to"]);
	return from === undefined || to === undefined ? undefined : { type: "move", move: { from, to } };
}

function squareFrom(value: unknown): Square | undefined {
	const square = asObject(value);
	const column = square?.["column"];
	const row = square?.["row"];
	if (!Number.isInteger(column) || !Number.isInteger(row)) {
		return undefined;
	}
	const parsed = squareAt(column as number, row as number);
	return Board.isInside(parsed) ? parsed : undefined;
}

function pieceTypeFrom(value: unknown): PieceType | undefined {
	return PIECE_TYPES.find((type) => type === value);
}
