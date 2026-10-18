class_name Nickname
extends RefCounted
## The rules for a Guest's nickname, as the online server checks them, so a
## Guest learns of a bad one before sending it. The server stays the judge.

## The game asks for at least two characters, a little stricter than the
## server, which takes one.
const MIN_LENGTH: int = 2
const MAX_LENGTH: int = 16

## Code point ranges of control characters (Unicode Cc) and of the invisible
## format characters (Unicode Cf) that could fake or hide a name. Godot's
## RegEx has no Unicode categories, so they are listed.
const _UNPRINTABLE_RANGES: Array[Vector2i] = [
	Vector2i(0x0000, 0x001F),
	Vector2i(0x007F, 0x009F),
	Vector2i(0x00AD, 0x00AD),
	Vector2i(0x0600, 0x0605),
	Vector2i(0x061C, 0x061C),
	Vector2i(0x06DD, 0x06DD),
	Vector2i(0x070F, 0x070F),
	Vector2i(0x180E, 0x180E),
	Vector2i(0x200B, 0x200F),
	Vector2i(0x202A, 0x202E),
	Vector2i(0x2060, 0x2064),
	Vector2i(0x2066, 0x206F),
	Vector2i(0xFEFF, 0xFEFF),
	Vector2i(0xFFF9, 0xFFFB),
]


## [param text] trimmed, or an empty String when it is not a valid nickname.
static func cleaned(text: String) -> String:
	var nickname: String = text.strip_edges()
	if nickname.length() < MIN_LENGTH or nickname.length() > MAX_LENGTH or _has_unprintable(nickname):
		return ""
	return nickname


static func _has_unprintable(text: String) -> bool:
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		for range: Vector2i in _UNPRINTABLE_RANGES:
			if code >= range.x and code <= range.y:
				return true
	return false
