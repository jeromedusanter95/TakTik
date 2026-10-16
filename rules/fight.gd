class_name Fight
extends RefCounted
## The record of one Attack: who fought and how it ended.

var attacker: Piece:
	get:
		return _attacker
var defender: Piece:
	get:
		return _defender
var outcome: FightOutcome.Id:
	get:
		return _outcome

var _attacker: Piece
var _defender: Piece
var _outcome: FightOutcome.Id


func _init(attacking: Piece, defending: Piece, result: FightOutcome.Id) -> void:
	_attacker = attacking
	_defender = defending
	_outcome = result


func eliminated() -> Array[Piece]:
	match _outcome:
		FightOutcome.Id.ATTACKER_WINS:
			return [_defender]
		FightOutcome.Id.DEFENDER_WINS:
			return [_attacker]
		_:
			return [_attacker, _defender]
