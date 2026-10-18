import type { RefereeAlarm } from "../referee/referee-alarm";

/** The referee's alarm as its Durable Object alarm, which rings even after hibernation. */
export class DurableObjectRefereeAlarm implements RefereeAlarm {
	constructor(private readonly storage: DurableObjectStorage) {}

	async setFor(time: number | undefined): Promise<void> {
		if (time === undefined) {
			await this.storage.deleteAlarm();
		} else {
			await this.storage.setAlarm(time);
		}
	}
}
