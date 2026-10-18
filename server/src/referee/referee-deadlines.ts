import type { ForfeitWatch } from "./forfeit-watch";
import type { RefereeAlarm } from "./referee-alarm";
import type { SetupTimer } from "./setup-timer";

/** The deadlines a referee keeps, and the one alarm they share: the Setup Timer during Setup, a Forfeit during play. */
export interface RefereeDeadlines {
	readonly setupTimer: SetupTimer;
	readonly forfeitWatch: ForfeitWatch;
	readonly alarm: RefereeAlarm;
}
