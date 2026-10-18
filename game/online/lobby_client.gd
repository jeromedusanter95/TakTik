class_name LobbyClient
extends RefCounted
## This Guest in the Lobby: who else is there, whether this Guest waits for a
## Quick Match, the Challenge they sent and the ones they received. Poll it
## once per frame; it ends at the first pairing or failure.

signal changed
signal paired(seat: PairedSeat)
signal failed(reason: String)
## A Challenge with [param nickname] is over, for [param reason] "declined",
## "withdrawn" or "gone".
signal challenge_ended(nickname: String, reason: String)

## The failure reported when the connection drops or never opens.
const CONNECTION_LOST: String = "connection_lost"

var _socket: WireSocket
var _active: bool = false
var _entered: bool = false
var _own_id: String = ""
var _guests: Array[ListedGuest] = []
var _waiting: bool = false
## The Guest this Guest challenged, or null.
var _challenged: ListedGuest = null
## The Guests who challenged this Guest, oldest first.
var _challengers: Array[ListedGuest] = []


func _init(socket: WireSocket) -> void:
	_socket = socket


## [param server_url] is the server's WebSocket origin, such as
## wss://example.workers.dev.
func enter(server_url: String, nickname: String) -> void:
	_active = true
	_socket.open(server_url + "/lobby")
	_socket.send_text(LobbyRequests.enter(nickname))


func is_active() -> bool:
	return _active


## True once the server let this Guest in.
func has_entered() -> bool:
	return _entered


## The id the server gave this Guest, once entered.
func own_id() -> String:
	return _own_id


## The other Guests, the longest there first.
func guests() -> Array[ListedGuest]:
	return _guests.duplicate()


func is_waiting() -> bool:
	return _waiting


## The Guest this Guest challenged, or null.
func challenged_guest() -> ListedGuest:
	return _challenged


func challengers() -> Array[ListedGuest]:
	return _challengers.duplicate()


func join_quick_match() -> void:
	_socket.send_text(LobbyRequests.quick_match())


func stop_waiting() -> void:
	_socket.send_text(LobbyRequests.stop_waiting())


func challenge(guest_id: String) -> void:
	_socket.send_text(LobbyRequests.challenge(guest_id))


func withdraw_challenge() -> void:
	_socket.send_text(LobbyRequests.withdraw_challenge())


func answer_challenge(guest_id: String, accept: bool) -> void:
	_socket.send_text(LobbyRequests.answer_challenge(guest_id, accept))
	if not accept:
		_forget_challenger(guest_id)
		changed.emit()


func poll() -> void:
	if not _active:
		return
	for text: String in _socket.poll():
		_handle(LobbyReplies.read(text))
		if not _active:
			return
	if _socket.state() == WireSocket.State.CLOSED:
		var reason: String = _socket.close_reason()
		_fail(reason if not reason.is_empty() else CONNECTION_LOST)


## Leaves the Lobby.
func leave() -> void:
	_active = false
	_socket.close()


func _handle(reply: LobbyReply) -> void:
	match reply.kind:
		LobbyReply.Kind.ENTERED:
			_entered = true
			_own_id = reply.guest_id
		LobbyReply.Kind.GUESTS:
			_guests = reply.guests
		LobbyReply.Kind.QUICK_MATCH:
			_waiting = reply.waiting
		LobbyReply.Kind.CHALLENGE_SENT:
			_challenged = _guest_named(reply.guest_id)
			_waiting = false
		LobbyReply.Kind.CHALLENGED:
			_forget_challenger(reply.guest_id)
			_challengers.append(ListedGuest.new(reply.guest_id, reply.nickname, false))
		LobbyReply.Kind.CHALLENGE_ENDED:
			_end_challenge(reply.guest_id, reply.reason)
		LobbyReply.Kind.PAIRED:
			_active = false
			_socket.close()
			paired.emit(reply.seat)
			return
		LobbyReply.Kind.REFUSED:
			if reply.reason == "invalid_nickname" or reply.reason == "game_unavailable":
				_fail(reply.reason)
			return
		_:
			return
	changed.emit()


func _end_challenge(guest_id: String, reason: String) -> void:
	var is_own_challenge: bool = _challenged != null and _challenged.guest_id == guest_id
	var nickname: String = _challenged.nickname if is_own_challenge else ""
	if is_own_challenge:
		_challenged = null
	for challenger: ListedGuest in _challengers:
		if challenger.guest_id == guest_id:
			nickname = challenger.nickname
	_forget_challenger(guest_id)
	if is_own_challenge and reason == "withdrawn":
		return
	challenge_ended.emit(nickname, reason)


func _forget_challenger(guest_id: String) -> void:
	_challengers = _challengers.filter(
		func(challenger: ListedGuest) -> bool: return challenger.guest_id != guest_id
	)


## The listed Guest with [param guest_id], or a placeholder when the listing
## has not caught up yet.
func _guest_named(guest_id: String) -> ListedGuest:
	for guest: ListedGuest in _guests:
		if guest.guest_id == guest_id:
			return guest
	return ListedGuest.new(guest_id, "", false)


func _fail(reason: String) -> void:
	_active = false
	_socket.close()
	failed.emit(reason)
