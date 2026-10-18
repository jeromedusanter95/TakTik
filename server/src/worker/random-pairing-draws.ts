import type { PairingDraws } from "../quick-match/quick-match-pairer";

const SEAT_TOKEN_BYTES = 32;

/** Draws from the runtime's cryptographic random source. */
export class RandomPairingDraws implements PairingDraws {
	seatToken(): string {
		const bytes = crypto.getRandomValues(new Uint8Array(SEAT_TOKEN_BYTES));
		return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
	}

	newcomerPlaysRed(): boolean {
		return (crypto.getRandomValues(new Uint8Array(1))[0] ?? 0) % 2 === 0;
	}
}
