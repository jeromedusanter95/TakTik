class_name Main
extends Node
## Composition root: builds what the game needs and hands it out.

@onready var _local_match: LocalMatch = %LocalMatch


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_local_match.start(func() -> HotSeatSession: return HotSeatSession.new(rng))
