import type { GameOpener } from "../quick-match/quick-match-pairer";
import type { Seating } from "../referee/seating";
import type { Referee } from "./referee";

/** Opens each game in a new Referee Durable Object. */
export class RefereeGameOpener implements GameOpener {
	constructor(private readonly referees: DurableObjectNamespace<Referee>) {}

	async open(seating: Seating): Promise<string> {
		const id = this.referees.newUniqueId();
		await this.referees.get(id).open(seating);
		return id.toString();
	}
}
