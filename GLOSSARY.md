# Taktik

A non-commercial web recreation of TakTik (Kickoo, 2002), a two-player turn-based board game originally released on Palm OS. Terms below come from the original in-game help (see `docs/reference/screenshots/`).

## Game

**Board**:
The playing area of 6 columns by 8 rows of Squares. Each player's side is the 3 rows nearest them; the 2 middle rows start empty.
_Avoid_: Grid, map, field

**Square**:
One cell of the Board, holding at most one Piece.
_Avoid_: Cell, tile, space

**Obstacle**:
One of the 4 Squares in the middle rows (columns 2 and 5) that no Piece can ever enter.
_Avoid_: Lake, wall, rock

**Army**:
The 18 Pieces one player controls, of 9 Piece Types. Player 1's Army is red, Player 2's Army is green.
_Avoid_: Team, side, deck

**Piece**:
A single unit of an Army standing on one Square of the Board.
_Avoid_: Unit, token, pawn

**Piece Type**:
One of the nine kinds of Piece, each with a fixed Attack Strength and Defense Strength: King, Executioner, Knight, Soldier, Magician, Buffoon, Monster, Thief, Princess.
_Avoid_: Class, rank, role

**Attack Strength**:
The number a Piece uses when it is the Attacker in a Fight.
_Avoid_: Power, damage

**Defense Strength**:
The number a Piece uses when it is the Defender in a Fight.
_Avoid_: Armor, health, HP

**Move**:
A Piece going forward, back, left or right (never diagonally) to a Square that is empty or holds an enemy Piece. Every Piece Type moves one Square except the Buffoon, which may cross any number of empty Squares in a straight line, and the Monster, which never moves.
_Avoid_: Action, step

**Attack**:
A Move whose destination Square holds an enemy Piece, which starts a Fight.
_Avoid_: Capture, strike

**Fight**:
The resolution of an Attack: the Attacker's Attack Strength against the Defender's Defense Strength. The stronger Piece wins and stays on the destination Square; on a tie both Pieces are eliminated. Two exceptions override the numbers: a Monster always beats its Attacker, except a Magician, which always beats the Monster.
_Avoid_: Battle, combat, duel

**Move Back**:
A Move that returns a Piece to the Square it just left. Forbidden until one Round has passed.
_Avoid_: Undo, retreat

**Graveyard**:
The set of eliminated Pieces of both Armies.
_Avoid_: Discard, captured pieces, cemetery

**Princess**:
The Piece Type a player must protect. It can never Attack. Losing it loses the game; bringing it to the enemy Home Row wins the game.
_Avoid_: Flag, queen

**Setup**:
The phase before play where each player places all 18 Pieces of their Army on their own side of the Board.
_Avoid_: Deployment, placement phase

**Hidden Piece**:
An enemy Piece shown without its Piece Type. Every enemy Piece is always a Hidden Piece on the Board, even after a Reveal.
_Avoid_: Fog, masked piece

**Reveal**:
The brief display of both Pieces' Piece Types and strengths when a Fight happens. Afterwards the surviving enemy Piece is a Hidden Piece again; players must remember what they saw.
_Avoid_: Flip, expose

**Home Row**:
The first row of a player's side of the Board, nearest that player.
_Avoid_: Back rank, first line, base

**Blocked**:
A player with no legal Move on their turn. A Blocked player loses.
_Avoid_: Stalemate, stuck

**Draw**:
The end of a game with no winner, reached after 50 Rounds with no Fight.
_Avoid_: Tie, stalemate

**Round**:
One Move by each player.
_Avoid_: Turn pair, cycle

**Victory**:
The end of a game, reached by capturing the enemy Princess, the opponent being Blocked, moving one's own Princess onto the enemy Home Row, or the opponent's Resign or Forfeit.
_Avoid_: Checkmate, win state

**Random Setup**:
A Setup where the game places all remaining Pieces for the player.
_Avoid_: QuickPlay, auto-place

**Saved Setup**:
A Setup layout a player stored to reuse in later games.
_Avoid_: Preset, configuration, template

## Play

**Guest**:
A player identified only by a chosen nickname, with no account.
_Avoid_: Anonymous user, visitor

**Bot**:
A computer opponent at one of three Difficulties. A Bot never sees Hidden Pieces.
_Avoid_: AI, CPU, computer

**Difficulty**:
The strength of a Bot: Easy, Medium or Hard.
_Avoid_: Level, skill

**Lobby**:
The place where online Guests see who else is online and find an Opponent.
_Avoid_: Room, hall

**Challenge**:
A direct invitation from one Guest to a specific Guest in the Lobby to play a game.
_Avoid_: Invite, request

**Quick Match**:
Being paired automatically with any other Guest who is also waiting.
_Avoid_: Matchmaking, queue, random match

**Turn Timer**:
The time a player has to make a Move in an online game. Running out loses the game.
_Avoid_: Clock, countdown

**Setup Timer**:
The time a player has to finish Setup in an online game. Pieces still unplaced when it runs out get a Random Setup.
_Avoid_: Placement timer

**Forfeit**:
Losing a game by disconnecting for too long, or by running out the Turn Timer.
_Avoid_: Abandon, timeout loss

**Resign**:
A player conceding the game on purpose, giving Victory to the Opponent.
_Avoid_: Surrender, give up, quit

**Rematch**:
A new game between the same two players, started only when both accept.
_Avoid_: Replay, revenge

**Quick Chat**:
One of a fixed set of messages a player can send during an online game.
_Avoid_: Chat, emote, message
