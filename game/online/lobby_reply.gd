class_name LobbyReply
extends RefCounted
## One message from the Lobby socket.

enum Kind {
	ENTERED,
	GUESTS,
	QUICK_MATCH,
	CHALLENGE_SENT,
	CHALLENGED,
	CHALLENGE_ENDED,
	PAIRED,
	REFUSED,
	MALFORMED,
}

var kind: Kind = Kind.MALFORMED
## ENTERED: this Guest's id. CHALLENGE_SENT, CHALLENGED and CHALLENGE_ENDED:
## the other Guest of the Challenge.
var guest_id: String = ""
## CHALLENGED: the nickname of the Guest who sent it.
var nickname: String = ""
## GUESTS: the other Guests, the longest there first.
var guests: Array[ListedGuest] = []
## QUICK_MATCH: whether this Guest now waits.
var waiting: bool = false
## CHALLENGE_ENDED: "declined", "withdrawn" or "gone". REFUSED: the refusal.
var reason: String = ""
## PAIRED: where to play.
var seat: PairedSeat = null
