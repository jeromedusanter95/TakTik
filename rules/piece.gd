class_name Piece
extends RefCounted
## A single unit of an Army.

var id: int:
	get:
		return _id
var type: PieceType.Id:
	get:
		return _type
var side: Side.Id:
	get:
		return _side

var _id: int
var _type: PieceType.Id
var _side: Side.Id


func _init(piece_id: int, piece_type: PieceType.Id, piece_side: Side.Id) -> void:
	_id = piece_id
	_type = piece_type
	_side = piece_side
