import { describe, expect, it } from "vitest";
import { formatLobbyReply, MAX_NICKNAME_LENGTH, parseLobbyRequest } from "../../src/lobby/protocol";

function text(message: unknown): string {
	return JSON.stringify(message);
}

describe("a Lobby request", () => {
	it("reads entering with a trimmed nickname", () => {
		expect(parseLobbyRequest(text({ type: "enter", nickname: "  Ada  " }))).toEqual({
			valid: true,
			request: { type: "enter", nickname: "Ada", inGame: false },
		});
	});

	it("reads entering while playing a game", () => {
		expect(parseLobbyRequest(text({ type: "enter", nickname: "Ada", inGame: true }))).toEqual({
			valid: true,
			request: { type: "enter", nickname: "Ada", inGame: true },
		});
	});

	it("refuses an in-game flag that is not true or false", () => {
		expect(parseLobbyRequest(text({ type: "enter", nickname: "Ada", inGame: "yes" }))).toEqual({
			valid: false,
			reason: "malformed_message",
		});
	});

	it("accepts a nickname of the longest allowed length, counted in characters", () => {
		const nickname = "é".repeat(MAX_NICKNAME_LENGTH);
		expect(parseLobbyRequest(text({ type: "enter", nickname }))).toEqual({ valid: true, request: { type: "enter", nickname, inGame: false } });
	});

	it.each([
		["empty", ""],
		["only spaces", "   "],
		["too long", "a".repeat(MAX_NICKNAME_LENGTH + 1)],
		["with a control character", "Ada\u0007"],
		["with an invisible format character", "A​da"],
		["not text", 42],
	])("refuses a nickname that is %s", (_, nickname) => {
		expect(parseLobbyRequest(text({ type: "enter", nickname }))).toEqual({ valid: false, reason: "invalid_nickname" });
	});

	it.each([
		[{ type: "quick_match" }],
		[{ type: "stop_waiting" }],
		[{ type: "challenge", guestId: "g1" }],
		[{ type: "withdraw_challenge" }],
		[{ type: "answer_challenge", guestId: "g1", accept: false }],
	])("reads %o", (message) => {
		expect(parseLobbyRequest(text(message))).toEqual({ valid: true, request: message });
	});

	it.each([
		["not JSON", "enter Ada"],
		["of an unknown type", text({ type: "dance" })],
		["a Challenge without a Guest", text({ type: "challenge" })],
		["a Challenge to an overlong id", text({ type: "challenge", guestId: "g".repeat(33) })],
		["an answer that is not a boolean", text({ type: "answer_challenge", guestId: "g1", accept: "yes" })],
	])("refuses a message that is %s", (_, message) => {
		expect(parseLobbyRequest(message)).toEqual({ valid: false, reason: "malformed_message" });
	});
});

describe("a Lobby reply", () => {
	it("is sent as JSON", () => {
		const reply = { type: "challenged", guestId: "g1", nickname: "Ada" } as const;
		expect(JSON.parse(formatLobbyReply(reply))).toEqual(reply);
	});
});
