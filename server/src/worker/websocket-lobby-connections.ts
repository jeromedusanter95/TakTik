import type { GuestState, LobbyConnections, LobbyGuest } from "../lobby/lobby";
import { formatLobbyReply, type LobbyRefusal, type LobbyReply } from "../lobby/protocol";
import { REFUSAL_CLOSE_CODE } from "../wire/close-codes";

/**
 * What a Lobby socket remembers about its Guest. Kept as the socket's
 * attachment, so it survives the Durable Object hibernating.
 */
type GuestStage = { readonly stage: "in_lobby"; readonly guest: GuestState } | { readonly stage: "paired" };

/** The Lobby sockets a Durable Object accepted with the Hibernation API. */
export class WebSocketLobbyConnections implements LobbyConnections<WebSocket> {
	constructor(private readonly ctx: DurableObjectState) {}

	guests(): readonly LobbyGuest<WebSocket>[] {
		return this.ctx
			.getWebSockets()
			.filter((socket) => socket.readyState === WebSocket.OPEN)
			.flatMap((socket) => {
				const stage = stageOf(socket);
				return stage?.stage === "in_lobby" ? [{ ...stage.guest, connection: socket }] : [];
			})
			.sort((first, second) => first.enteredAt - second.enteredAt);
	}

	stateOf(connection: WebSocket): GuestState | undefined {
		const stage = stageOf(connection);
		return stage?.stage === "in_lobby" ? stage.guest : undefined;
	}

	hasEntered(connection: WebSocket): boolean {
		return stageOf(connection) !== undefined;
	}

	setState(connection: WebSocket, state: GuestState): void {
		setStage(connection, { stage: "in_lobby", guest: state });
	}

	markPaired(connection: WebSocket): void {
		setStage(connection, { stage: "paired" });
	}

	send(connection: WebSocket, reply: LobbyReply): void {
		if (connection.readyState === WebSocket.OPEN) {
			connection.send(formatLobbyReply(reply));
		}
	}

	refuseAndClose(connection: WebSocket, reason: LobbyRefusal): void {
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
