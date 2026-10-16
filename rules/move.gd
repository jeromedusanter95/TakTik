class_name Move
extends RefCounted
## A Piece going from one Square to another.

var from: Vector2i:
	get:
		return _from
var to: Vector2i:
	get:
		return _to

var _from: Vector2i
var _to: Vector2i


func _init(from_square: Vector2i, to_square: Vector2i) -> void:
	_from = from_square
	_to = to_square


func equals(other: Move) -> bool:
	return other != null and other.from == _from and other.to == _to
