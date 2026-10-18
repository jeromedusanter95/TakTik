import { formatRefereeReply, type RefereeRefusal, type RefereeReply } from "../referee/protocol";
import type { SeatConnections } from "../referee/referee-session";
import type { Side } from "../rules/side";
import { REFUSAL_CLOSE_CODE } from "../wire/close-codes";

/**
 * What a game socket remembers: the side it took and whether its player asks
 * for a Rematch. Kept as its attachment, so it survives hibernation.
 */
interface SeatAttachment {
	readonly side: Side;
	readonly wantsRematch?: boolean;
}

/** The sockets of one game, accepted by its Referee with the Hibernation API. */
export class WebSocketSeatConnections implements SeatConnections<WebSocket> {
	constructor(private readonly ctx: DurableObjectState) {}

	sideOf(connection: WebSocket): Side | undefined {
		return (connection.deserializeAttachment() as SeatAttachment | null)?.side;
	}

	seat(connection: WebSocket, side: Side): void {
		const attachment: SeatAttachment = { side };
		connection.serializeAttachment(attachment);
	}

	markWantsRematch(connection: WebSocket): void {
		const side = this.sideOf(connection);
		if (side !== undefined) {
			const attachment: SeatAttachment = { side, wantsRematch: true };
			connection.serializeAttachment(attachment);
		}
	}

	wantsRematch(side: Side): boolean {
		return this.connectionsOf(side).some(
			(socket) => (socket.deserializeAttachment() as SeatAttachment | null)?.wantsRematch === true,
		);
	}

	connectionsOf(side: Side): readonly WebSocket[] {
		return this.ctx
			.getWebSockets()
			.filter((socket) => socket.readyState === WebSocket.OPEN && this.sideOf(socket) === side);
	}

	send(connection: WebSocket, reply: RefereeReply): void {
		if (connection.readyState === WebSocket.OPEN) {
			connection.send(formatRefereeReply(reply));
		}
	}

	refuseAndClose(connection: WebSocket, reason: RefereeRefusal): void {
		if (connection.readyState === WebSocket.OPEN) {
			connection.close(REFUSAL_CLOSE_CODE, reason);
		}
	}
}
