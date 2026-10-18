import { formatQuickMatchReply, type QuickMatchReply, type RefusalReason } from "../quick-match/protocol";
import type { GuestConnections, WaitingGuest } from "../quick-match/quick-match-pairer";
import { REFUSAL_CLOSE_CODE } from "../wire/close-codes";

/**
 * What a Quick Match socket remembers about its Guest. Kept as the socket's
 * attachment, so it survives the Durable Object hibernating.
 */
type GuestStage =
	| { readonly stage: "waiting"; readonly nickname: string; readonly joinedAt: number }
	| { readonly stage: "paired" };

/** The Quick Match sockets a Durable Object accepted with the Hibernation API. */
export class WebSocketGuestConnections implements GuestConnections<WebSocket> {
	constructor(private readonly ctx: DurableObjectState) {}

	waitingGuests(): readonly WaitingGuest<WebSocket>[] {
		return this.ctx
			.getWebSockets()
			.filter((socket) => socket.readyState === WebSocket.OPEN)
			.flatMap((socket) => {
				const stage = stageOf(socket);
				return stage?.stage === "waiting" ? [{ socket, nickname: stage.nickname, joinedAt: stage.joinedAt }] : [];
			})
			.sort((first, second) => first.joinedAt - second.joinedAt)
			.map(({ socket, nickname }) => ({ connection: socket, nickname }));
	}

	hasJoined(connection: WebSocket): boolean {
		return stageOf(connection) !== undefined;
	}

	markWaiting(connection: WebSocket, nickname: string): void {
		setStage(connection, { stage: "waiting", nickname, joinedAt: Date.now() });
	}

	markPaired(connection: WebSocket): void {
		setStage(connection, { stage: "paired" });
	}

	send(connection: WebSocket, reply: QuickMatchReply): void {
		if (connection.readyState === WebSocket.OPEN) {
			connection.send(formatQuickMatchReply(reply));
		}
	}

	refuseAndClose(connection: WebSocket, reason: RefusalReason): void {
		if (connection.readyState === WebSocket.OPEN) {
			connection.close(REFUSAL_CLOSE_CODE, reason);
		}
	}
}

function stageOf(socket: WebSocket): GuestStage | undefined {
	return (socket.deserializeAttachment() as GuestStage | null) ?? undefined;
}

function setStage(socket: WebSocket, stage: GuestStage): void {
	socket.serializeAttachment(stage);
}
