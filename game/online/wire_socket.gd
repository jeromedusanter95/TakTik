@abstract
class_name WireSocket
extends RefCounted
## A text connection to the online server, read by polling once per frame.

enum State {
	CONNECTING,
	OPEN,
	CLOSED,
}


## Starts connecting, dropping any earlier connection.
@abstract func open(url: String) -> void


## Sends [param text], or keeps it until the connection is open.
@abstract func send_text(text: String) -> void


## The messages received since the last poll, oldest first.
@abstract func poll() -> PackedStringArray


@abstract func state() -> State


## Why the server closed the connection, from its close frame, or an empty
## String. The server closes with the refusal as reason, because the message
## sent just before the close can be lost.
@abstract func close_reason() -> String


@abstract func close() -> void
