import { DurableObject } from "cloudflare:workers";
import { QuickMatchPairer } from "../quick-match/quick-match-pairer";
import { RandomPairingDraws } from "./random-pairing-draws";
import { RefereeGameOpener } from "./referee-game-opener";
import { WebSocketGuestConnections } from "./websocket-guest-connections";

/** The one Durable Object every Quick Match socket connects to. */
export class QuickMatchHost extends DurableObject<Env> {
	private readonly pairer: QuickMatchPairer<WebSocket>;

	constructor(ctx: DurableObjectState, env: Env) {
		super(ctx, env);
		this.pairer = new QuickMatchPairer(
			new WebSocketGuestConnections(ctx),
			new RefereeGameOpener(env.REFEREE),
			new RandomPairingDraws(),
		);
	}

	override async fetch(): Promise<Response> {
		const [client, server] = Object.values(new WebSocketPair()) as [WebSocket, WebSocket];
		this.ctx.acceptWebSocket(server);
		return new Response(null, { status: 101, webSocket: client });
	}

	override async webSocketMessage(socket: WebSocket, message: string | ArrayBuffer): Promise<void> {
		const text = typeof message === "string" ? message : new TextDecoder().decode(message);
		await this.pairer.receive(socket, text);
	}
}
