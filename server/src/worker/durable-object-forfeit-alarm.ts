import type { ForfeitAlarm } from "../referee/forfeit-watch";

/** The forfeit alarm as its Referee's Durable Object alarm, which rings even after hibernation. */
export class DurableObjectForfeitAlarm implements ForfeitAlarm {
	constructor(private readonly storage: DurableObjectStorage) {}

	async setFor(time: number | undefined): Promise<void> {
		if (time === undefined) {
			await this.storage.deleteAlarm();
		} else {
			await this.storage.setAlarm(time);
		}
	}
}
