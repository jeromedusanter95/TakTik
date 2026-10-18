class_name PiecePicture
extends TextureRect
## One Piece's token outside the Board, in a card or a Graveyard tray, shown
## grey once it is eliminated.

const GrayscaleShader: Shader = preload("res://game/ui/components/grayscale.gdshader")


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grey: ShaderMaterial = ShaderMaterial.new()
	grey.shader = GrayscaleShader
	material = grey


## Shows [param type] of [param side]'s Army, grey when [param eliminated].
func show_piece(
		type: PieceType.Id, side: Side.Id, eliminated: bool = false, adapted: bool = false
) -> void:
	texture = PieceArt.token(type, side, adapted)
	set_grey(1.0 if eliminated else 0.0)


## Shows the back of a Hidden Piece of [param side].
func show_hidden(side: Side.Id, adapted: bool = false) -> void:
	texture = PieceArt.hidden(side, adapted)
	set_grey(0.0)


## How grey the Piece looks, from 0 to 1.
func set_grey(amount: float) -> void:
	var grey: ShaderMaterial = material
	grey.set_shader_parameter(&"amount", amount)
