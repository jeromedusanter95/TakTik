import { DurableObject } from "cloudflare:workers";
import type { Seating } from "../referee/seating";

const SEATING_KEY = "seating";

/**
 * The referee of one online game. For now it only records who holds each
 * seat; refereeing the game itself comes next.
 */
export class Referee extends DurableObject<Env> {
	/** Rejects when this game already has its seats. */
	async open(seating: Seating): Promise<void> {
		if ((await this.ctx.storage.get(SEATING_KEY)) !== undefined) {
			throw new Error("This game is already open");
		}
		await this.ctx.storage.put(SEATING_KEY, seating);
	}
}
