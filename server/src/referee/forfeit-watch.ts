import { SIDES, type Side } from "../rules/side";
import type { Clock } from "./clock";

/** When each side that is away lost its last socket, in milliseconds since the epoch. Plain data, so it can be stored. */
export type AbsenceRecord = Readonly<Partial<Record<Side, number>>>;

/** Keeps a game's absences safe across restarts. */
export interface AbsenceStore {
	saveAbsences(record: AbsenceRecord): Promise<void>;
}

/** What a ForfeitWatch needs from outside: the delay, the time and where absences are kept. */
export interface ForfeitWatchSettings {
	readonly forfeitAfterMs: number;
	readonly clock: Clock;
	readonly store: AbsenceStore;
}

/**
 * Knows which players are disconnected and since when, and so when the first
 * of them will have been away long enough to Forfeit.
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

	/** When the longest absent player will have been away long enough to Forfeit, or undefined when no one is away. */
	firstDeadline(): number | undefined {
		return this.byDeadline()[0]?.[1];
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
