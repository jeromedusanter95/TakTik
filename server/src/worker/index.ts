export { LobbyHost } from "./lobby-host";
export { Referee } from "./referee";

/** All Guests share one Lobby, so it is a single, named Durable Object. */
const LOBBY_NAME = "lobby";

const GAME_PATH = /^\/games\/([0-9a-f]{64})$/;

export default {
	async fetch(request, env): Promise<Response> {
		const url = new URL(request.url);
		const stub = durableObjectFor(url.pathname, env);
		if (stub === undefined) {
			return new Response("Not found", { status: 404 });
		}
		if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
			return new Response("Expected a WebSocket upgrade", { status: 426 });
		}
		return stub.fetch(request);
	},
} satisfies ExportedHandler<Env>;

/** The Durable Object a path leads to: the Lobby, or the Referee of one game. */
function durableObjectFor(path: string, env: Env): { fetch(request: Request): Promise<Response> } | undefined {
	if (path === "/lobby") {
		return env.LOBBY.getByName(LOBBY_NAME);
	}
	const gameId = GAME_PATH.exec(path)?.[1];
	if (gameId === undefined) {
		return undefined;
	}
	try {
		return env.REFEREE.get(env.REFEREE.idFromString(gameId));
	} catch {
		return undefined;
	}
}
