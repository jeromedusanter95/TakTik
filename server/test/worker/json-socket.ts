/** A test client's WebSocket that records every JSON reply until the server closes it. */
export class JsonSocket<Reply> {
	readonly replies: Reply[] = [];
	readonly closed: Promise<void>;
	private waiters: (() => void)[] = [];

	private constructor(private readonly socket: WebSocket) {
		socket.addEventListener("message", (event) => {
			this.replies.push(JSON.parse(String(event.data)) as Reply);
			this.waiters.forEach((wake) => wake());
			this.waiters = [];
		});
		this.closed = new Promise((resolve) => socket.addEventListener("close", () => resolve()));
	}

	static async open<Reply>(url: URL): Promise<JsonSocket<Reply>> {
		const socket = new WebSocket(url);
		await new Promise<void>((resolve, reject) => {
			socket.addEventListener("open", () => resolve());
			socket.addEventListener("error", () => reject(new Error(`the socket to ${url.pathname} could not open`)));
		});
		return new JsonSocket<Reply>(socket);
	}

	send(message: unknown): void {
		this.socket.send(JSON.stringify(message));
	}

	leave(): void {
		this.socket.close();
	}

	/** Every reply so far, once there are at least [count]. */
	async replyCount(count: number): Promise<Reply[]> {
		while (this.replies.length < count) {
			await new Promise<void>((wake) => this.waiters.push(wake));
		}
		return this.replies;
	}

	/** The reply at [index], once it has arrived. */
	async reply(index: number): Promise<Reply> {
		const replies = await this.replyCount(index + 1);
		return replies[index] as Reply;
	}
}

/** The WebSocket URL of [path] on the local server at [base]. */
export function socketUrl(base: URL, path: string): URL {
	return new URL(path, base.href.replace(/^http/, "ws"));
}
