class_name WebSocketWireSocket
extends WireSocket
## A WireSocket over Godot's WebSocketPeer, which the web export runs on the
## browser's own WebSocket.

var _peer: WebSocketPeer = WebSocketPeer.new()
var _outbox: PackedStringArray = []
var _failed: bool = false


func open(url: String) -> void:
	_peer = WebSocketPeer.new()
	_outbox.clear()
	_failed = _peer.connect_to_url(url) != OK


func send_text(text: String) -> void:
	if _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_peer.send_text(text)
	else:
		_outbox.append(text)


func poll() -> PackedStringArray:
	_peer.poll()
	if _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		for text: String in _outbox:
			_peer.send_text(text)
		_outbox.clear()
	var received: PackedStringArray = []
	while _peer.get_available_packet_count() > 0:
		received.append(_peer.get_packet().get_string_from_utf8())
	return received


func state() -> State:
	if _failed:
		return State.CLOSED
	match _peer.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			return State.CONNECTING
		WebSocketPeer.STATE_OPEN:
			return State.OPEN
		_:
			return State.CLOSED


func close_reason() -> String:
	return _peer.get_close_reason() if _peer.get_ready_state() == WebSocketPeer.STATE_CLOSED else ""


func close() -> void:
	_peer.close()
