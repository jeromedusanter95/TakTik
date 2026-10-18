/** Wakes the referee at a set time. A referee has one, shared by every deadline it keeps. */
export interface RefereeAlarm {
	/** Replaces any earlier alarm; undefined cancels it. */
	setFor(time: number | undefined): Promise<void>;
}
