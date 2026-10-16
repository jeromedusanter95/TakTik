class_name MoveRecord
extends RefCounted
## What happened when a Move was played.

var move: Move:
	get:
		return _move
var mover: Piece:
	get:
		return _mover
## The Fight the Move caused, or null for a simple Move.
var fight: Fight:
	get:
		return _fight

var _move: Move
var _mover: Piece
var _fight: Fight


func _init(played: Move, moving_piece: Piece, caused_fight: Fight) -> void:
	_move = played
	_mover = moving_piece
	_fight = caused_fight
