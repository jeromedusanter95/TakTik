class_name LobbyReplies
extends RefCounted
## Reads the messages of the Lobby socket into typed replies. Anything that
## does not have the expected shape becomes a MALFORMED reply, never a crash.


static func read(text: String) -> LobbyReply:
	var reply: LobbyReply = LobbyReply.new()
	var message: Dictionary = WireJson.parsed_object(text)
	match message.get("type"):
		"entered":
			_read_guest_id(message, reply, LobbyReply.Kind.ENTERED)
		"guests":
			_read_guests(message, reply)
		"quick_match":
			_read_quick_match(message, reply)
		"challenge_sent":
			_read_guest_id(message, reply, LobbyReply.Kind.CHALLENGE_SENT)
		"challenged":
			reply.nickname = WireJson.text(message.get("nickname"))
			_read_guest_id(message, reply, LobbyReply.Kind.CHALLENGED)
		"challenge_ended":
			reply.reason = WireJson.text(message.get("reason"))
			_read_guest_id(message, reply, LobbyReply.Kind.CHALLENGE_ENDED)
		"paired":
			_read_paired(message, reply)
		"refused":
			reply.reason = WireJson.text(message.get("reason"))
			reply.kind = LobbyReply.Kind.REFUSED
	return reply


static func _read_guest_id(message: Dictionary, reply: LobbyReply, kind: LobbyReply.Kind) -> void:
	reply.guest_id = WireJson.text(message.get("guestId"))
	if not reply.guest_id.is_empty():
		reply.kind = kind


static func _read_guests(message: Dictionary, reply: LobbyReply) -> void:
	var listed: Variant = message.get("guests")
	if listed is not Array:
		return
	var items: Array = listed
	for item: Variant in items:
		var guest: Dictionary = WireJson.object(item)
		var guest_id: String = WireJson.text(guest.get("guestId"))
		var waiting: Variant = guest.get("waiting")
		if guest_id.is_empty() or waiting is not bool:
			return
		var is_waiting: bool = waiting
		reply.guests.append(ListedGuest.new(guest_id, WireJson.text(guest.get("nickname")), is_waiting))
	reply.kind = LobbyReply.Kind.GUESTS


static func _read_quick_match(message: Dictionary, reply: LobbyReply) -> void:
	var waiting: Variant = message.get("waiting")
	if waiting is not bool:
		return
	reply.waiting = waiting
	reply.kind = LobbyReply.Kind.QUICK_MATCH


static func _read_paired(message: Dictionary, reply: LobbyReply) -> void:
	reply.seat = PairedSeatReader.read(message)
	if reply.seat != null:
		reply.kind = LobbyReply.Kind.PAIRED
