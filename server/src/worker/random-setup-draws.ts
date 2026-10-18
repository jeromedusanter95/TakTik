import type { SetupDraws } from "../rules/setup";

const RANGE = 2 ** 32;

/** Draws from the runtime's cryptographic random source, each choice equally likely. */
export class RandomSetupDraws implements SetupDraws {
	below(count: number): number {
		const unbiasedLimit = RANGE - (RANGE % count);
		for (;;) {
			const value = crypto.getRandomValues(new Uint32Array(1))[0] ?? 0;
			if (value < unbiasedLimit) {
				return value % count;
			}
		}
	}
}
