extends WireSocket
## A WireSocket the test feeds with server messages and reads what was sent.

var opened_url: String = ""
var sent: PackedStringArray = []
var current_state: WireSocket.State = WireSocket.State.CLOSED
var server_close_reason: String = ""
var open_count: int = 0
var _inbox: PackedStringArray = []


func open(url: String) -> void:
	opened_url = url
	open_count += 1
	current_state = WireSocket.State.OPEN


func send_text(text: String) -> void:
	sent.append(text)


func poll() -> PackedStringArray:
	var received: PackedStringArray = _inbox
	_inbox = []
	return received


func state() -> WireSocket.State:
	return current_state


func close_reason() -> String:
	return server_close_reason


func close() -> void:
	current_state = WireSocket.State.CLOSED


## The server closing the connection with [param reason] in the close frame.
func close_from_server(reason: String) -> void:
	server_close_reason = reason
	current_state = WireSocket.State.CLOSED


## Queues a message from the server for the next poll.
func receive(message: Dictionary) -> void:
	_inbox.append(JSON.stringify(message))


## The last message sent, read back as JSON.
func last_sent() -> Dictionary:
	var value: Variant = JSON.parse_string(sent[sent.size() - 1]) if not sent.is_empty() else {}
	return value if value is Dictionary else {}
