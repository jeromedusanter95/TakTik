import type { TurnDeadlineStore } from "../referee/turn-timer";

const TURN_DEADLINE_KEY = "turn_deadline";

/** Keeps when a game's current turn runs out in its Referee's own Durable Object storage. */
export class DurableObjectTurnDeadlineStore implements TurnDeadlineStore {
	constructor(private readonly storage: DurableObjectStorage) {}

	/** Milliseconds since the epoch, or undefined before the first turn or for a game started before the Turn Timer existed. */
	async load(): Promise<number | undefined> {
		return this.storage.get<number>(TURN_DEADLINE_KEY);
	}

	async saveTurnDeadline(deadline: number): Promise<void> {
		await this.storage.put(TURN_DEADLINE_KEY, deadline);
	}
}
