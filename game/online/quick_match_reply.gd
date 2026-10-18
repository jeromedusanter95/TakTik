class_name QuickMatchReply
extends RefCounted
## One message from the Quick Match socket.

enum Kind {
	WAITING,
	PAIRED,
	REFUSED,
	MALFORMED,
}

var kind: Kind = Kind.MALFORMED
## Only for PAIRED.
var seat: PairedSeat = null
## Only for REFUSED: the server's reason, for example "invalid_nickname".
var refusal: String = ""
