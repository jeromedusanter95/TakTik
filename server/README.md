# Taktik online server

A Cloudflare Worker, as decided in [ADR 0001](../docs/adr/0001-cloudflare-referee-with-rules-written-twice.md).

- `src/rules`: the rules in TypeScript, checked by the shared rule cases in [spec/rules](../spec/rules/README.md).
- `src/quick-match`: the Quick Match protocol and pairing logic, plain TypeScript with no Cloudflare types.
- `src/worker`: the Worker entry and the Durable Objects, thin adapters around the code above.
  - `QuickMatchHost`: one named instance every Quick Match socket connects to.
  - `Referee`: one instance per online game. For now it only records the seats.

## Quick Match

A Guest opens a WebSocket on `/quick-match` and sends `{"type":"join","nickname":"Ada"}`.
The server answers `{"type":"waiting"}`, then, once paired, `{"type":"paired","gameId":…,"side":"red"|"green","seatToken":…,"opponent":…}` and closes the socket.
A refused join gets `{"type":"refused","reason":…}` and a closed socket.
The messages are defined in [src/quick-match/protocol.ts](src/quick-match/protocol.ts).

## Commands

```bash
npm test
```

Typechecks everything and runs the unit tests in Node.

```bash
npm run test:worker
```

Starts the real Worker locally through wrangler's test harness and talks to it over WebSockets.
`@cloudflare/vitest-pool-workers` is not used because it only supports vitest 4.

```bash
npm run dev
```

Serves the Worker on `http://localhost:8787`.

```bash
npm run types
```

Regenerates `src/worker/worker-configuration.d.ts` after a change to `wrangler.jsonc`.
