class_name UiFonts
extends RefCounted
## The two typefaces: Lilita One for display and titles, Nunito for the rest
## at the weights the design uses.

const _LILITA_ONE: FontFile = preload("res://game/ui/fonts/lilita_one_regular.ttf")
const _NUNITO: FontFile = preload("res://game/ui/fonts/nunito.ttf")

static var _display: FontVariation = null
static var _weights: Dictionary[int, FontVariation] = {}


## Lilita One, with Nunito behind it for the characters it lacks.
static func display() -> Font:
	if _display == null:
		_display = FontVariation.new()
		_display.base_font = _LILITA_ONE
		_display.fallbacks = [nunito(800)]
	return _display


## Nunito at [param weight], such as 700, 800 or 900.
static func nunito(weight: int) -> Font:
	if not _weights.has(weight):
		var font: FontVariation = FontVariation.new()
		font.base_font = _NUNITO
		font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_weights[weight] = font
	return _weights[weight]
