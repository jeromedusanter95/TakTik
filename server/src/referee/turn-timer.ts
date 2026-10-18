import type { Clock } from "./clock";

/** Keeps when the current turn runs out safe across restarts. */
export interface TurnDeadlineStore {
	saveTurnDeadline(deadline: number): Promise<void>;
}

/** What a TurnTimer needs from outside: how long a turn lasts, the time and where its deadline is kept. */
export interface TurnTimerSettings {
	readonly turnMs: number;
	readonly clock: Clock;
	readonly store: TurnDeadlineStore;
}

/**
 * The Turn Timer of one online game: the time the player to move has to make
 * a Move. Running it out loses the game by Forfeit.
 */
export class TurnTimer {
	/** [deadline] is in milliseconds since the epoch, or undefined before the first turn starts. */
	constructor(
		private current: number | undefined,
		private readonly settings: TurnTimerSettings,
	) {}

	/** When the current turn runs out, or undefined before the first turn starts. */
	deadline(): number | undefined {
		return this.current;
	}

	/** Starts a new turn now. */
	async restart(): Promise<void> {
		this.current = this.settings.clock.now() + this.settings.turnMs;
		await this.settings.store.saveTurnDeadline(this.current);
	}

	isUp(): boolean {
		return this.current !== undefined && this.settings.clock.now() >= this.current;
	}

	/** Milliseconds until the current turn runs out, never below zero; a whole turn before the first one starts. */
	timeLeftMs(): number {
		if (this.current === undefined) {
			return this.settings.turnMs;
		}
		return Math.max(0, this.current - this.settings.clock.now());
	}
}
