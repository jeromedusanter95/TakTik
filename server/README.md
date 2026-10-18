# Taktik online server

A Cloudflare Worker, as decided in [ADR 0001](../docs/adr/0001-cloudflare-referee-with-rules-written-twice.md).

- `src/rules`: the rules in TypeScript, checked by the shared rule cases in [spec/rules](../spec/rules/README.md).
- `src/lobby`: the Lobby protocol and rules (Quick Match and Challenges), plain TypeScript with no Cloudflare types.
- `src/referee`: the game protocol, the online game (Setups, Moves, what each side may see) and the session that referees it over sockets, also free of Cloudflare types.
- `src/worker`: the Worker entry and the Durable Objects, thin adapters around the code above.
  - `LobbyHost`: one named instance every Lobby socket connects to.
  - `Referee`: one instance per online game. It stores the record (seats, both Setups, every Move, a Resign or Forfeit) and who is away, and rebuilds the game from them when it wakes from hibernation. Its alarm rings when an away player would Forfeit.

## The Lobby

A Guest opens a WebSocket on `/lobby` and sends `{"type":"enter","nickname":"Ada"}`.
The server answers `entered` with the Guest's id, then `guests` with the other Guests whenever that list changes.
From there a Guest either:

- sends `quick_match` and is paired with the next Guest who does the same (`stop_waiting` leaves the queue), or
- sends `challenge` with another Guest's id. That Guest gets `challenged` and answers with `answer_challenge`; a declined, withdrawn or abandoned Challenge ends with `challenge_ended`.

Once paired, both Guests get `paired` with the game id, their side and their Seat Token, and close their own socket.
A refused request gets `refused`; a socket the server shows out also carries the refusal as its close reason.
The messages are defined in [src/lobby/protocol.ts](src/lobby/protocol.ts).

## Playing a game

Each paired Guest opens a WebSocket on `/games/<gameId>` and first sends `{"type":"take_seat","seatToken":…}`.
A Seat Token travels only inside a message, never in a URL.
The referee answers `seated` with the side and the Opponent's nickname, then where the game stands:

- During Setup, `setup_status` tells whether each side has handed in its Setup. A Guest sends `{"type":"setup","placements":[{"square":{"column":0,"row":0},"type":"king"},…]}`, one placement per Square of their three rows.
- Once both Setups are in, each Guest gets `game_state` with their own `PlayerView` and the public `history` of every Move so far.
- A Guest sends `{"type":"move","move":{"from":…,"to":…}}`. Both Guests then get `moved` with the public Move event and their own `PlayerView`.
- When a Move ends the game, `moved` also carries `finalBoard`: every Piece left, with its Piece Type.
- A Guest sends `{"type":"resign"}` to Resign during play. Both Guests then get `game_state` with the result (`"reason":"resigned"`) and `finalBoard`.
- When a Guest's last socket closes, their Opponent gets `{"type":"opponent_presence","connected":false}`, and `"connected":true` once they take their seat again. A Guest taking their seat while the Opponent is away also gets `"connected":false`.
- A Guest who stays away during play for `FORFEIT_AFTER_SECONDS` (in `wrangler.jsonc`) Forfeits: both get `game_state` with `"reason":"forfeited"`. The clock counts during Setup too, but a Forfeit only happens once play has started.
- A wrong message gets `refused` with a reason. A socket that never took a seat is then closed; a seated one stays open.

- At any time, a Guest may send `{"type":"quick_chat","message":"good_luck"}`, one of a fixed set (`QUICK_CHAT_MESSAGES`); both Guests get it back as `quick_chat` with its sender's side.
- Once the game is over, a Guest may send `rematch`. The Opponent gets `rematch_offered`; when both have asked, both get `rematch_ready` with their seat in a new game, sides swapped.

Taking a seat again, from a new tab or after a dropped connection, moves the seat to the new socket, closes the old one and resends the game so far.
The messages are defined in [src/referee/protocol.ts](src/referee/protocol.ts).

## Playing against a local server

Run `npm run dev`, set `online_server_url` on the Main node to `ws://localhost:8787` in the Godot editor (without saving it), and choose Play online in two game windows.
`test/online/online_smoke.gd` plays a whole game between two headless clients through the running server:

```bash
Godot --headless --path .. -s test/online/online_smoke.gd
```

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
npm run deploy
```

Deploys the Worker to Cloudflare after a one-time `npx wrangler login`.
Its address, `wss://taktik-referee.<your subdomain>.workers.dev`, goes into `online_server_url` on the Main node in `main.tscn`.

```bash
npm run types
```

Regenerates `src/worker/worker-configuration.d.ts` after a change to `wrangler.jsonc`.
