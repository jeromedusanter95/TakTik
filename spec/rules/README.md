# Shared rule test cases

These JSON files are the single source of truth for Taktik's rules. Every implementation of the rules (the GDScript engine in the Godot client, the TypeScript referee on the server) must pass all of them. See `docs/adr/0001-cloudflare-referee-with-rules-written-twice.md`.

A rules change is done only when a case here describes it and both implementations pass.

## Notation

**Squares** use columns `a` to `f` (left to right, as Red sees the Board) and ranks `1` to `8` (bottom to top). Rank 1 is Red's Home Row, rank 8 is Green's Home Row.

**Boards** are 8 strings of 6 characters, listed from rank 8 (top) down to rank 1 (bottom):

| Character | Meaning |
|---|---|
| `.` | empty Square |
| `#` | Obstacle (always `b4`, `b5`, `e4`, `e5`) |
| `K` `E` `N` `S` `M` `B` `O` `T` `P` | Red King, Executioner, Knight, Soldier, Magician, Buffoon, Monster, Thief, Princess |
| lowercase of the above | the same Piece Type for Green |

**Moves** are written `from-to`, for example `c3-c4`.

## Case files

Each file holds `{ "cases": [ ... ] }`.

### Play cases

```json
{
  "name": "what this proves",
  "board": ["8 strings"],
  "to_move": "red",
  "plies_without_fight": 0,
  "moves": ["c3-c4"],
  "expect": {
    "legal_moves": { "c4": ["c5", "d4"] },
    "illegal_moves": ["c4-c3"],
    "board": ["8 strings"],
    "fight": { "attacker": "N", "defender": "s", "outcome": "attacker_wins" },
    "status": "in_progress",
    "reason": "none"
  }
}
```

1. Build the Board, set the side to move (`plies_without_fight` is optional, default 0).
2. Play every entry of `moves` in order; each must be legal.
3. Check every key present in `expect` (all are optional):
   - `legal_moves`: for each origin Square, the exact set of legal destinations, in any order.
   - `illegal_moves`: each must be rejected, leaving the game unchanged.
   - `board`: the Board after the moves.
   - `fight`: the Fight caused by the last move. `outcome` is `attacker_wins`, `defender_wins` or `both_eliminated`.
   - `status`: `in_progress`, `red_wins`, `green_wins` or `draw`.
   - `reason`: `none`, `princess_captured`, `princess_reached_home_row`, `blocked` or `no_fight_limit`.

### Setup cases (`setup.json`)

```json
{ "name": "...", "side": "red", "rows": ["3 strings"], "valid": true }
```

`rows` are the side's three setup ranks, top to bottom: ranks 3, 2, 1 for Red and ranks 8, 7, 6 for Green. `valid` says whether this is a legal Setup (exactly the Army, every setup Square filled).
