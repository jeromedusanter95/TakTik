class_name Side
extends RefCounted
## The two Armies. Red is Player 1, starts at the bottom and moves first.

enum Id {
	RED,
	GREEN,
}


static func opponent(side: Id) -> Id:
	return Id.GREEN if side == Id.RED else Id.RED
