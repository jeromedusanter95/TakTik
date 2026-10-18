import type { AbsenceRecord, AbsenceStore } from "../referee/forfeit-watch";

const ABSENCES_KEY = "absences";

/** Keeps who is away from a game, and since when, in its Referee's own Durable Object storage. */
export class DurableObjectAbsenceStore implements AbsenceStore {
	constructor(private readonly storage: DurableObjectStorage) {}

	async load(): Promise<AbsenceRecord> {
		return (await this.storage.get<AbsenceRecord>(ABSENCES_KEY)) ?? {};
	}

	async saveAbsences(record: AbsenceRecord): Promise<void> {
		await this.storage.put(ABSENCES_KEY, record);
	}
}
