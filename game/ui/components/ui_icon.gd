class_name UiIcon
extends TextureRect
## A Lucide line icon tinted with one of the design's text colours.

enum Tone {
	PRIMARY,
	SECONDARY,
	MUTED,
	FAINT,
	GOLD,
	ON_GOLD,
	GREEN,
}

const _COLOURS: Dictionary[Tone, Color] = {
	Tone.PRIMARY: UiTokens.TEXT_PRIMARY,
	Tone.SECONDARY: UiTokens.TEXT_SECONDARY,
	Tone.MUTED: UiTokens.TEXT_MUTED,
	Tone.FAINT: UiTokens.TEXT_FAINT,
	Tone.GOLD: UiTokens.GOLD_TEXT,
	Tone.ON_GOLD: UiTokens.TEXT_ON_GOLD,
	Tone.GREEN: UiTokens.GREEN_400,
}

@export var tone: Tone = Tone.MUTED:
	set(value):
		tone = value
		self_modulate = _COLOURS[value]


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	self_modulate = _COLOURS[tone]
