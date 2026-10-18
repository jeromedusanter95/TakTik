import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { createTestHarness, type TestHarness } from "wrangler";
import type { LobbyReply } from "../../src/lobby/protocol";
import { JsonSocket, socketUrl } from "./json-socket";

type GuestSocket = JsonSocket<LobbyReply>;

describe("the Lobby Worker", () => {
	let harness: TestHarness;
	let lobbyUrl: URL;

	beforeAll(async () => {
		harness = createTestHarness({ workers: [{ configPath: "./wrangler.jsonc" }] });
		await harness.listen();
	});

	beforeEach(async () => {
		await harness.reset();
		lobbyUrl = socketUrl((await harness.listen()).url, "/lobby");
	});

	afterAll(async () => {
		await harness.close();
	});

	/** A Guest who entered the Lobby, and their Guest id. */
	async function enter(nickname: string): Promise<{ guest: GuestSocket; guestId: string }> {
		const guest = await JsonSocket.open<LobbyReply>(lobbyUrl);
		guest.send({ type: "enter", nickname });
		const entered = await guest.replyWhere((reply) => reply.type === "entered");
		return { guest, guestId: entered.type === "entered" ? entered.guestId : "" };
	}

	async function pairedReplyOf(guest: GuestSocket): Promise<Extract<LobbyReply, { type: "paired" }>> {
		const reply = await guest.replyWhere((candidate) => candidate.type === "paired");
		if (reply.type !== "paired") {
			throw new Error("not paired");
		}
		return reply;
	}

	it("lists the Guests in the Lobby to each other", async () => {
		const ada = await enter("Ada");
		const bob = await enter("Bob");

		const adaSees = await ada.guest.replyWhere(
			(reply) => reply.type === "guests" && reply.guests.some((listed) => listed.nickname === "Bob"),
		);
		expect(adaSees).toEqual({ type: "guests", guests: [{ guestId: bob.guestId, nickname: "Bob", waiting: false }] });
	});

	it("pairs two Guests through Quick Match into one game on opposite sides", async () => {
		const ada = await enter("Ada");
		const bob = await enter("Bob");
		ada.guest.send({ type: "quick_match" });
		await ada.guest.replyWhere((reply) => reply.type === "quick_match");
		bob.guest.send({ type: "quick_match" });

		const [adaPaired, bobPaired] = await Promise.all([pairedReplyOf(ada.guest), pairedReplyOf(bob.guest)]);
		expect(adaPaired.gameId).toBe(bobPaired.gameId);
		expect([adaPaired.side, bobPaired.side].sort()).toEqual(["green", "red"]);
		expect(adaPaired.seatToken).toMatch(/^[0-9a-f]{64}$/);
		expect(adaPaired.opponent).toBe("Bob");
	});

	it("pairs a Guest with the one they challenged once the Challenge is accepted", async () => {
		const ada = await enter("Ada");
		const bob = await enter("Bob");
		ada.guest.send({ type: "challenge", guestId: bob.guestId });
		const challenged = await bob.guest.replyWhere((reply) => reply.type === "challenged");
		expect(challenged).toEqual({ type: "challenged", guestId: ada.guestId, nickname: "Ada" });

		bob.guest.send({ type: "answer_challenge", guestId: ada.guestId, accept: true });
		const [adaPaired, bobPaired] = await Promise.all([pairedReplyOf(ada.guest), pairedReplyOf(bob.guest)]);
		expect(adaPaired.gameId).toBe(bobPaired.gameId);
		expect(bobPaired.opponent).toBe("Ada");
	});

	it("tells the Guest challenged when the sender leaves the Lobby", async () => {
		const ada = await enter("Ada");
		const bob = await enter("Bob");
		ada.guest.send({ type: "challenge", guestId: bob.guestId });
		await bob.guest.replyWhere((reply) => reply.type === "challenged");
		ada.guest.leave();

		expect(await bob.guest.replyWhere((reply) => reply.type === "challenge_ended")).toEqual({
			type: "challenge_ended",
			guestId: ada.guestId,
			reason: "gone",
		});
	});

	it("refuses an invalid nickname with the reason in the close frame", async () => {
		const guest = await JsonSocket.open<LobbyReply>(lobbyUrl);
		guest.send({ type: "enter", nickname: "   " });

		expect(await guest.reply(0)).toEqual({ type: "refused", reason: "invalid_nickname" });
		expect(await guest.closed).toBe("invalid_nickname");
	});

	it("answers anything but a WebSocket upgrade with 426", async () => {
		expect((await harness.fetch("/lobby")).status).toBe(426);
	});

	it("answers an unknown path, including the old Quick Match one, with 404", async () => {
		expect((await harness.fetch("/quick-match")).status).toBe(404);
		expect((await harness.fetch("/nothing-here")).status).toBe(404);
	});
});
