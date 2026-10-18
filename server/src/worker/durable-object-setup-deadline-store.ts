const SETUP_DEADLINE_KEY = "setup_deadline";

/** Keeps when a game's Setup Timer runs out in its Referee's own Durable Object storage. */
export class DurableObjectSetupDeadlineStore {
	constructor(private readonly storage: DurableObjectStorage) {}

	/** Milliseconds since the epoch, or undefined for a game opened before the Setup Timer existed. */
	async load(): Promise<number | undefined> {
		return this.storage.get<number>(SETUP_DEADLINE_KEY);
	}

	async save(deadline: number): Promise<void> {
		await this.storage.put(SETUP_DEADLINE_KEY, deadline);
	}
}
