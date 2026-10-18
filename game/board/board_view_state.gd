class_name BoardViewState
extends RefCounted
## Everything BoardView needs to draw one frame of the Board.

const NO_SQUARE: Vector2i = Vector2i(-1, -1)

var board: Board = Board.new()
## Whose eyes the Board is shown to: their Pieces are drawn at the bottom and
## enemy Pieces are drawn as Hidden Pieces.
var viewer: Side.Id = Side.Id.RED
## Shows every Piece Type, for the end of the game.
var reveal_all: bool = false
var selected: Vector2i = NO_SQUARE
var destinations: Array[Vector2i] = []
## The last Move played, or null.
var last_move: Move = null
## During Setup: covers the enemy's rows with stripes and this label, since
## their Army stays hidden.
var cover_enemy_zone: bool = false
var enemy_zone_label: String = ""
## Draws the green Army blue, for colour-blind players.
var adapted_colours: bool = false
