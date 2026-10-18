import { DurableObject } from "cloudflare:workers";
import { Lobby } from "../lobby/lobby";
import { RandomLobbyDraws } from "./random-lobby-draws";
import { RefereeGameOpener } from "./referee-game-opener";
import { WebSocketLobbyConnections } from "./websocket-lobby-connections";

/** The one Durable Object every Lobby socket connects to. */
export class LobbyHost extends DurableObject<Env> {
	private readonly lobby: Lobby<WebSocket>;

	constructor(ctx: DurableObjectState, env: Env) {
		super(ctx, env);
		this.lobby = new Lobby(
			new WebSocketLobbyConnections(ctx),
			new RefereeGameOpener(env.REFEREE),
			new RandomLobbyDraws(),
			{ now: () => Date.now() },
		);
	}

	override async fetch(): Promise<Response> {
		const [client, server] = Object.values(new WebSocketPair()) as [WebSocket, WebSocket];
		this.ctx.acceptWebSocket(server);
		return new Response(null, { status: 101, webSocket: client });
	}

	override async webSocketMessage(socket: WebSocket, message: string | ArrayBuffer): Promise<void> {
		const text = typeof message === "string" ? message : new TextDecoder().decode(message);
		await this.lobby.receive(socket, text);
	}

	override async webSocketClose(socket: WebSocket): Promise<void> {
		this.lobby.leave(socket);
	}
}
