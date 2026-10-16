class_name DecidedThinking
extends BotThinking
## A turn whose Move was chosen up front, such as a deliberate mistake.

var _move: Move


func _init(move: Move) -> void:
	_move = move


func step() -> void:
	pass


func is_done() -> bool:
	return true


func chosen_move() -> Move:
	return _move
