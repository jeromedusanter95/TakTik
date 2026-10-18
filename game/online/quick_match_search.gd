class_name QuickMatchSearch
extends RefCounted
## Looks for an Opponent through Quick Match. Poll it once per frame; it
## reports through its signals and ends at the first pairing or failure.

signal waiting_started
signal paired(seat: PairedSeat)
signal failed(reason: String)

## The failure reported when the connection drops or never opens.
const CONNECTION_LOST: String = "connection_lost"

var _socket: WireSocket
var _searching: bool = false


func _init(socket: WireSocket) -> void:
	_socket = socket


## [param server_url] is the server's WebSocket origin, such as
## wss://example.workers.dev.
func start(server_url: String, nickname: String) -> void:
	_searching = true
	_socket.open(server_url + "/quick-match")
	_socket.send_text(OnlineRequests.join(nickname))


func is_searching() -> bool:
	return _searching


func poll() -> void:
	if not _searching:
		return
	for text: String in _socket.poll():
		_handle(OnlineReplies.quick_match(text))
		if not _searching:
			return
	if _socket.state() == WireSocket.State.CLOSED:
		var reason: String = _socket.close_reason()
		_fail(reason if not reason.is_empty() else CONNECTION_LOST)


## Stops looking and leaves Quick Match.
func cancel() -> void:
	_searching = false
	_socket.close()


func _handle(reply: QuickMatchReply) -> void:
	match reply.kind:
		QuickMatchReply.Kind.WAITING:
			waiting_started.emit()
		QuickMatchReply.Kind.PAIRED:
			_searching = false
			_socket.close()
			paired.emit(reply.seat)
		QuickMatchReply.Kind.REFUSED:
			_fail(reply.refusal)


func _fail(reason: String) -> void:
	_searching = false
	_socket.close()
	failed.emit(reason)
