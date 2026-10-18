class_name LobbyRequests
extends RefCounted
## The messages this client sends on the Lobby socket, as JSON text.


## [param in_game] enters a Guest who is playing a game: listed, but out of
## reach of Challenges and Quick Match.
static func enter(nickname: String, in_game: bool = false) -> String:
	if in_game:
		return JSON.stringify({"type": "enter", "nickname": nickname, "inGame": true})
	return JSON.stringify({"type": "enter", "nickname": nickname})


static func quick_match() -> String:
	return JSON.stringify({"type": "quick_match"})


static func stop_waiting() -> String:
	return JSON.stringify({"type": "stop_waiting"})


static func challenge(guest_id: String) -> String:
	return JSON.stringify({"type": "challenge", "guestId": guest_id})


static func withdraw_challenge() -> String:
	return JSON.stringify({"type": "withdraw_challenge"})


static func answer_challenge(guest_id: String, accept: bool) -> String:
	return JSON.stringify({"type": "answer_challenge", "guestId": guest_id, "accept": accept})
