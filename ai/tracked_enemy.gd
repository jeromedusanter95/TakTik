class_name TrackedEnemy
extends RefCounted
## What a Bot remembers about one enemy Piece: its Piece Type once a Reveal
## or its way of moving gave it away, and whether it has ever moved.

var _is_known: bool = false
var _known_type: PieceType.Id = PieceType.Id.KING
var _has_moved: bool = false


func is_known() -> bool:
	return _is_known


## Only meaningful when [method is_known] is true.
func known_type() -> PieceType.Id:
	return _known_type


## A Piece that has moved can never be a Monster.
func has_moved() -> bool:
	return _has_moved


func learn_type(type: PieceType.Id) -> void:
	_is_known = true
	_known_type = type


func mark_moved() -> void:
	_has_moved = true
