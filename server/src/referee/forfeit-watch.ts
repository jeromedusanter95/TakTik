import { SIDES, type Side } from "../rules/side";

/** When each side that is away lost its last socket, in milliseconds since the epoch. Plain data, so it can be stored. */
export type AbsenceRecord = Readonly<Partial<Record<Side, number>>>;

/** Keeps a game's absences safe across restarts. */
export interface AbsenceStore {
	saveAbsences(record: AbsenceRecord): Promise<void>;
}

/** Wakes the referee at a set time, to Forfeit whoever stayed away too long. */
export interface ForfeitAlarm {
	/** Replaces any earlier alarm; undefined cancels it. */
	setFor(time: number | undefined): Promise<void>;
}

export interface Clock {
	now(): number;
}

/** What a ForfeitWatch needs from outside: the delay and the ports it uses. */
export interface ForfeitWatchSettings {
	readonly forfeitAfterMs: number;
	readonly clock: Clock;
	readonly store: AbsenceStore;
	readonly alarm: ForfeitAlarm;
}

/**
 * Knows which players are disconnected and since when, and keeps an alarm set
 * for the moment the first of them has been away long enough to Forfeit.
 */
export class ForfeitWatch {
	private readonly awaySince: Map<Side, number>;

	constructor(
		record: AbsenceRecord,
		private readonly settings: ForfeitWatchSettings,
	) {
		this.awaySince = new Map(SIDES.flatMap((side) => (record[side] === undefined ? [] : [[side, record[side]]])));
	}

	isAway(side: Side): boolean {
		return this.awaySince.has(side);
	}

	/** Starts [side]'s absence now, unless it already started. */
	async left(side: Side): Promise<void> {
		if (this.isAway(side)) {
			return;
		}
		this.awaySince.set(side, this.settings.clock.now());
		await this.settings.store.saveAbsences(this.toRecord());
	}

	async returned(side: Side): Promise<void> {
		if (this.awaySince.delete(side)) {
			await this.settings.store.saveAbsences(this.toRecord());
		}
	}

	/** The side that has been away long enough to Forfeit, the longest absent first, or undefined. */
	overdue(): Side | undefined {
		const now = this.settings.clock.now();
		return this.byDeadline().find(([, deadline]) => deadline <= now)?.[0];
	}

	/** Sets the alarm for the first deadline while play goes on; cancels it otherwise. */
	async arm(playing: boolean): Promise<void> {
		const first = playing ? this.byDeadline()[0]?.[1] : undefined;
		await this.settings.alarm.setFor(first);
	}

	private byDeadline(): [Side, number][] {
		return [...this.awaySince]
			.map(([side, since]): [Side, number] => [side, since + this.settings.forfeitAfterMs])
			.toSorted(([, first], [, second]) => first - second);
	}

	private toRecord(): AbsenceRecord {
		return Object.fromEntries(this.awaySince);
	}
}
