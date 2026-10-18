import type { GameOpener } from "../lobby/game-opener";
import type { OpenedRematch, RematchMaker } from "../referee/rematch-maker";
import type { Seating } from "../referee/seating";
import type { Side } from "../rules/side";

/** Draws the secret of a seat. */
export interface SeatTokens {
	seatToken(): string;
}

/** Opens a Rematch in a new Referee, with new Seat Tokens. */
export class RefereeRematchMaker implements RematchMaker {
	constructor(
		private readonly opener: GameOpener,
		private readonly tokens: SeatTokens,
	) {}

	async open(nicknames: Readonly<Record<Side, string>>): Promise<OpenedRematch> {
		const seating: Seating = {
			red: { nickname: nicknames.red, seatToken: this.tokens.seatToken() },
			green: { nickname: nicknames.green, seatToken: this.tokens.seatToken() },
		};
		return { gameId: await this.opener.open(seating), seating };
	}
}
