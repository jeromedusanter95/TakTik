class_name ScreenLayout
extends RefCounted
## The four layouts of the UI handoff, chosen by the screen's width in CSS
## pixels: the board always stays the largest element, and the chat and the
## side cards give way first.

enum Id {
	## 1280 and up: three columns, at the 1440 by 900 reference size.
	WIDE,
	## 1024 to 1279: player strips around the Board, a narrower chat column.
	MEDIUM,
	## 700 to 1023: player strips, the chat in a drawer from the right.
	NARROW,
	## Under 700: everything stacked, the chat in a bottom sheet.
	PHONE,
}

const WIDE_FROM: float = 1280.0
const MEDIUM_FROM: float = 1024.0
const NARROW_FROM: float = 700.0


static func for_width(css_width: float) -> Id:
	if css_width >= WIDE_FROM:
		return Id.WIDE
	if css_width >= MEDIUM_FROM:
		return Id.MEDIUM
	if css_width >= NARROW_FROM:
		return Id.NARROW
	return Id.PHONE


## The reference size the window is drawn at for [param layout], given the
## screen's [param css_size]: the design sizes for wide screens and phones,
## the screen itself in between, so text keeps its size.
static func content_size(layout: Id, css_size: Vector2) -> Vector2i:
	match layout:
		Id.WIDE:
			return UiTokens.DESKTOP_SIZE
		Id.PHONE:
			return UiTokens.PHONE_SIZE
		_:
			return Vector2i(roundi(css_size.x), roundi(maxf(css_size.y, 480.0)))
