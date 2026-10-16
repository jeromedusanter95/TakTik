# Online games are refereed by Cloudflare Durable Objects, with the rules written twice

Every Piece is a Hidden Piece to the opponent, so no client may ever hold the full game state: a server must own it, validate every Move, resolve every Fight and send each player only what they may see. The budget is €0/month with no credit card, so we chose Cloudflare Workers with one SQLite-backed Durable Object per online game (WebSocket Hibernation, state persisted in DO storage because memory is wiped on hibernation). The cost is that the rules exist twice: in GDScript inside the Godot client (legal-move highlighting, local play, Bots) and in TypeScript in the Worker (referee). A shared, language-neutral suite of rule test cases (JSON fixtures: position, Move, expected outcome) must pass against both implementations; a rules change is not done until both pass.

## Considered Options

- **Godot headless server on Oracle Cloud Always Free**: one GDScript rules codebase, but needs a credit card and Oracle reclaims idle free VMs (under 20% use over 7 days), which a small game server trips.
- **Supabase Realtime**: a relay, not an authoritative server; Edge Functions cap at about 150 s, and free projects pause after 7 days of low activity.
- **Render / Koyeb free tiers**: sleep when idle and lose in-memory games on restart. Fly.io has no free tier for new accounts.
- **Peer-to-peer relay with no referee**: impossible with Hidden Pieces without leaking them, and open to cheating.

## Consequences

- The Godot client is served from GitHub Pages, not Cloudflare Pages, because Cloudflare caps static files at 25 MiB and the Godot engine `.wasm` is larger. The export is single-threaded (Godot's default since 4.3), so no COOP/COEP headers are needed.
- The free plan has hard daily caps (100k DO requests, 13,000 GB-s): going over returns errors, never a bill.
- Bot games and local games never touch the server.

Research and sources: checked 2026-10-16 (Cloudflare DO pricing and limits docs, Supabase limits, Oracle Always Free docs, Godot 4.7 web export docs).
