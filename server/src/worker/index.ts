export { QuickMatchHost } from "./quick-match-host";
export { Referee } from "./referee";

/** All Guests share one Quick Match, so it is a single, named Durable Object. */
const QUICK_MATCH_NAME = "quick-match";

export default {
	async fetch(request, env): Promise<Response> {
		const url = new URL(request.url);
		if (url.pathname !== "/quick-match") {
			return new Response("Not found", { status: 404 });
		}
		if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
			return new Response("Expected a WebSocket upgrade", { status: 426 });
		}
		return env.QUICK_MATCH.getByName(QUICK_MATCH_NAME).fetch(request);
	},
} satisfies ExportedHandler<Env>;
