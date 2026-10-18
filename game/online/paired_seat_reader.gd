class_name PairedSeatReader
extends RefCounted
## Reads a seat in a new game, as the Lobby sends it when pairing and the
## referee sends it for a Rematch.


## The seat [param message] describes, or null when it is malformed.
static func read(message: Dictionary) -> PairedSeat:
	var side_name: Variant = message.get("side")
	var game_id: String = WireJson.text(message.get("gameId"))
	var seat_token: String = WireJson.text(message.get("seatToken"))
	if not WireNames.is_side(side_name) or game_id.is_empty() or seat_token.is_empty():
		return null
	var seat: PairedSeat = PairedSeat.new()
	seat.game_id = game_id
	seat.side = WireNames.side(side_name)
	seat.seat_token = seat_token
	seat.opponent = WireJson.text(message.get("opponent"))
	return seat
