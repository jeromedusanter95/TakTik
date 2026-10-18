class_name PieceArt
extends RefCounted
## The token pictures for every Piece Type of each Army, and the Hidden Piece back.

const _RED_TOKENS: Dictionary[PieceType.Id, Texture2D] = {
	PieceType.Id.KING: preload("res://game/art/king_red.svg"),
	PieceType.Id.EXECUTIONER: preload("res://game/art/executioner_red.svg"),
	PieceType.Id.KNIGHT: preload("res://game/art/knight_red.svg"),
	PieceType.Id.SOLDIER: preload("res://game/art/soldier_red.svg"),
	PieceType.Id.MAGICIAN: preload("res://game/art/magician_red.svg"),
	PieceType.Id.BUFFOON: preload("res://game/art/buffoon_red.svg"),
	PieceType.Id.MONSTER: preload("res://game/art/monster_red.svg"),
	PieceType.Id.THIEF: preload("res://game/art/thief_red.svg"),
	PieceType.Id.PRINCESS: preload("res://game/art/princess_red.svg"),
}
const _GREEN_TOKENS: Dictionary[PieceType.Id, Texture2D] = {
	PieceType.Id.KING: preload("res://game/art/king_green.svg"),
	PieceType.Id.EXECUTIONER: preload("res://game/art/executioner_green.svg"),
	PieceType.Id.KNIGHT: preload("res://game/art/knight_green.svg"),
	PieceType.Id.SOLDIER: preload("res://game/art/soldier_green.svg"),
	PieceType.Id.MAGICIAN: preload("res://game/art/magician_green.svg"),
	PieceType.Id.BUFFOON: preload("res://game/art/buffoon_green.svg"),
	PieceType.Id.MONSTER: preload("res://game/art/monster_green.svg"),
	PieceType.Id.THIEF: preload("res://game/art/thief_green.svg"),
	PieceType.Id.PRINCESS: preload("res://game/art/princess_green.svg"),
}
const _RED_HIDDEN: Texture2D = preload("res://game/art/hidden_red.svg")
const _GREEN_HIDDEN: Texture2D = preload("res://game/art/hidden_green.svg")
## The hues of the green Army's art, and the blue they turn into for players
## who chose adapted colours.
const _GREEN_HUES: Vector2 = Vector2(0.2, 0.47)
const _BLUE_HUE_SHIFT: float = 0.24
const _MIN_SATURATION: float = 0.2

static var _adapted: Dictionary[Texture2D, Texture2D] = {}


## The token of [param type] for [param side]. With [param adapted], the green
## Army is drawn blue, for colour-blind players.
static func token(type: PieceType.Id, side: Side.Id, adapted: bool = false) -> Texture2D:
	if side == Side.Id.RED:
		return _RED_TOKENS[type]
	return _adapt(_GREEN_TOKENS[type]) if adapted else _GREEN_TOKENS[type]


## The faceless back shown for an enemy piece whose type is still unknown.
static func hidden(side: Side.Id, adapted: bool = false) -> Texture2D:
	if side == Side.Id.RED:
		return _RED_HIDDEN
	return _adapt(_GREEN_HIDDEN) if adapted else _GREEN_HIDDEN


## [param green_art] with its greens turned blue, made once and kept.
static func _adapt(green_art: Texture2D) -> Texture2D:
	if _adapted.has(green_art):
		return _adapted[green_art]
	var image: Image = green_art.get_image()
	if image == null:
		return green_art
	image.decompress()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var colour: Color = image.get_pixel(x, y)
			if colour.a > 0.0 and colour.s >= _MIN_SATURATION and colour.h >= _GREEN_HUES.x and colour.h <= _GREEN_HUES.y:
				colour.h = colour.h + _BLUE_HUE_SHIFT
				image.set_pixel(x, y, colour)
	var blue: ImageTexture = ImageTexture.create_from_image(image)
	_adapted[green_art] = blue
	return blue
