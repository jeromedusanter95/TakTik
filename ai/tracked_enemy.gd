class_name TrackedEnemy
extends RefCounted
## What a Bot remembers about one enemy Piece: its Piece Type once a Reveal
## or its way of moving gave it away, whether it has ever moved, and how much
## its behaviour so far suggests each Piece Type.

var _is_known: bool = false
var _known_type: PieceType.Id = PieceType.Id.KING
var _has_moved: bool = false
var _likelihoods: Dictionary[PieceType.Id, float] = {}


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


## How well [param type] fits this Piece's behaviour, relative to the other
## types: 1.0 until some behaviour counts against it.
func likelihood(type: PieceType.Id) -> float:
	return _likelihoods.get(type, 1.0)


## Multiplies the likelihood of [param type] by [param factor].
func weigh(type: PieceType.Id, factor: float) -> void:
	_likelihoods[type] = likelihood(type) * factor
