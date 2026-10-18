import type { LobbyDraws } from "../lobby/lobby";

const SEAT_TOKEN_BYTES = 32;
const GUEST_ID_BYTES = 8;

/** Draws from the runtime's cryptographic random source. */
export class RandomLobbyDraws implements LobbyDraws {
	guestId(): string {
		return randomHex(GUEST_ID_BYTES);
	}

	seatToken(): string {
		return randomHex(SEAT_TOKEN_BYTES);
	}

	firstPlaysRed(): boolean {
		return (crypto.getRandomValues(new Uint8Array(1))[0] ?? 0) % 2 === 0;
	}
}

function randomHex(byteCount: number): string {
	const bytes = crypto.getRandomValues(new Uint8Array(byteCount));
	return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}
