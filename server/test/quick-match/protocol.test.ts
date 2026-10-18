import { describe, expect, it } from "vitest";
import { formatQuickMatchReply, MAX_NICKNAME_LENGTH, parseQuickMatchRequest } from "../../src/quick-match/protocol";

function joinText(nickname: unknown): string {
	return JSON.stringify({ type: "join", nickname });
}

describe("a Quick Match request", () => {
	it("reads a join with the Guest's nickname", () => {
		expect(parseQuickMatchRequest(joinText("Ada"))).toEqual({ valid: true, request: { type: "join", nickname: "Ada" } });
	});

	it("trims the spaces around the nickname", () => {
		expect(parseQuickMatchRequest(joinText("  Ada  "))).toEqual({ valid: true, request: { type: "join", nickname: "Ada" } });
	});

	it("accepts a nickname of the longest allowed length, counted in characters", () => {
		const nickname = "é".repeat(MAX_NICKNAME_LENGTH);
		expect(parseQuickMatchRequest(joinText(nickname))).toEqual({ valid: true, request: { type: "join", nickname } });
	});

	it.each([
		["empty", ""],
		["only spaces", "   "],
		["too long", "a".repeat(MAX_NICKNAME_LENGTH + 1)],
		["with a control character", "Ada\u0007"],
		["with an invisible format character", "A​da"],
		["not text", 42],
	])("refuses a nickname that is %s", (_, nickname) => {
		expect(parseQuickMatchRequest(joinText(nickname))).toEqual({ valid: false, reason: "invalid_nickname" });
	});

	it.each([
		["not JSON", "join Ada"],
		["not an object", "[]"],
		["null", "null"],
		["of an unknown type", JSON.stringify({ type: "dance", nickname: "Ada" })],
		["without a type", JSON.stringify({ nickname: "Ada" })],
	])("refuses a message that is %s", (_, text) => {
		expect(parseQuickMatchRequest(text)).toEqual({ valid: false, reason: "malformed_message" });
	});
});

describe("a Quick Match reply", () => {
	it("is sent as JSON", () => {
		const reply = { type: "paired", gameId: "g1", side: "green", seatToken: "t1", opponent: "Ada" } as const;
		expect(JSON.parse(formatQuickMatchReply(reply))).toEqual(reply);
	});
});
