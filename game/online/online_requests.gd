class_name OnlineRequests
extends RefCounted
## The messages this client sends to the online server, as JSON text.


static func join(nickname: String) -> String:
	return JSON.stringify({"type": "join", "nickname": nickname})


static func take_seat(seat_token: String) -> String:
	return JSON.stringify({"type": "take_seat", "seatToken": seat_token})


static func setup(arrangement: Setup) -> String:
	var placements: Array[Dictionary] = []
	for square: Vector2i in Setup.squares_for(arrangement.side):
		placements.append({
			"square": _square(square),
			"type": WireNames.piece_type_name(arrangement.type_at(square)),
		})
	return JSON.stringify({"type": "setup", "placements": placements})


static func move(played: Move) -> String:
	return JSON.stringify({
		"type": "move",
		"move": {"from": _square(played.from), "to": _square(played.to)},
	})


static func resign() -> String:
	return JSON.stringify({"type": "resign"})


static func _square(square: Vector2i) -> Dictionary[String, int]:
	return {"column": square.x, "row": square.y}
