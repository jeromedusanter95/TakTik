import type { ForfeitWatch } from "./forfeit-watch";
import type { RefereeAlarm } from "./referee-alarm";
import type { SetupTimer } from "./setup-timer";
import type { TurnTimer } from "./turn-timer";

/**
 * The deadlines a referee keeps, and the one alarm they share: the Setup Timer
 * during Setup, the Turn Timer and the Forfeit of an absent player during play.
 */
export interface RefereeDeadlines {
	readonly setupTimer: SetupTimer;
	readonly turnTimer: TurnTimer;
	readonly forfeitWatch: ForfeitWatch;
	readonly alarm: RefereeAlarm;
}
