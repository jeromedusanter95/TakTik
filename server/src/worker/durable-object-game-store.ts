import type { GameRecord } from "../referee/online-game";
import type { GameStore } from "../referee/referee-session";

const RECORD_KEY = "game";

/** Keeps a game's record in its Referee's own Durable Object storage. */
export class DurableObjectGameStore implements GameStore {
	constructor(private readonly storage: DurableObjectStorage) {}

	async load(): Promise<GameRecord | undefined> {
		return this.storage.get<GameRecord>(RECORD_KEY);
	}

	async save(record: GameRecord): Promise<void> {
		await this.storage.put(RECORD_KEY, record);
	}
}
