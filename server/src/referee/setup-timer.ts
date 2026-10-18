import type { Clock } from "./clock";

/**
 * The time the players of one online game have to finish Setup. When it runs
 * out, each side still without a Setup gets a Random Setup.
 */
export class SetupTimer {
	/** [deadline] is in milliseconds since the epoch. */
	constructor(
		readonly deadline: number,
		private readonly clock: Clock,
	) {}

	isUp(): boolean {
		return this.clock.now() >= this.deadline;
	}

	/** Milliseconds until it runs out, never below zero. */
	timeLeftMs(): number {
		return Math.max(0, this.deadline - this.clock.now());
	}
}
