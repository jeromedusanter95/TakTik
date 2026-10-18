class_name SoundCue
extends RefCounted
## The moments the game marks with a sound. Each has a visual twin on screen
## (a banner, a card, a pill), so muting loses nothing.

enum Id {
	MOVE,
	SWAP,
	FIGHT,
	CAPTURE,
	TURN,
	TICK,
	CHAT,
	CHALLENGE,
	VICTORY,
	DEFEAT,
}
