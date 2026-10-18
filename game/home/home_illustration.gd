class_name HomeIllustration
extends Control
## The decoration beside the home menu: the red and green Kings and a Hidden
## Piece floating over a tilted Board, with crossed swords between them. It
## ignores the mouse.

const FLOAT_HEIGHT: float = 12.0
const FLOAT_PERIODS: Array[float] = [4.4, 4.8, 5.2]
const PLANE_ALPHA: float = 0.2

var _pieces: Array[Control] = []
var _tweens: Array[Tween] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pieces.append(_add_piece(PieceArt.token(PieceType.Id.KING, Side.Id.RED), 206.0, -8.0, Vector2(0.06, 0.14)))
	_pieces.append(_add_piece(PieceArt.token(PieceType.Id.KING, Side.Id.GREEN), 176.0, 9.0, Vector2(0.44, 0.5)))
	_pieces.append(_add_piece(PieceArt.hidden(Side.Id.GREEN), 96.0, 14.0, Vector2(0.1, 0.74)))
	_add_swords(Vector2(0.4, 0.38))
	resized.connect(queue_redraw)


func _draw() -> void:
	# A Board seen at a slant: each row narrower towards the top.
	var rows: int = 8
	var columns: int = 6
	var bottom_width: float = size.x * 1.05
	var top_width: float = size.x * 0.55
	var top: float = size.y * 0.42
	var bottom: float = size.y * 0.98
	for row: int in rows:
		var y0: float = lerpf(bottom, top, float(row) / rows)
		var y1: float = lerpf(bottom, top, float(row + 1) / rows)
		var w0: float = lerpf(bottom_width, top_width, float(row) / rows)
		var w1: float = lerpf(bottom_width, top_width, float(row + 1) / rows)
		for column: int in columns:
			var left0: float = size.x / 2.0 - w0 / 2.0 + w0 * column / columns
			var right0: float = left0 + w0 / columns
			var left1: float = size.x / 2.0 - w1 / 2.0 + w1 * column / columns
			var right1: float = left1 + w1 / columns
			var colour: Color = UiTokens.CELL_DARK if (row + column) % 2 == 0 else UiTokens.CELL_LIGHT
			draw_colored_polygon(
				[Vector2(left0, y0), Vector2(right0, y0), Vector2(right1, y1), Vector2(left1, y1)],
				Color(colour, PLANE_ALPHA)
			)


## Starts or stops the floating, for reduced motion.
func set_floating(floating: bool) -> void:
	for tween: Tween in _tweens:
		tween.kill()
	_tweens.clear()
	if not floating:
		return
	for index: int in _pieces.size():
		var piece: Control = _pieces[index]
		var rest: float = piece.position.y
		var half: float = FLOAT_PERIODS[index] / 2.0
		var tween: Tween = create_tween().set_loops()
		tween.tween_property(piece, "position:y", rest - FLOAT_HEIGHT, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(piece, "position:y", rest, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tweens.append(tween)


func _add_piece(texture: Texture2D, diameter: float, degrees: float, anchor: Vector2) -> Control:
	var picture: PiecePicture = PiecePicture.new()
	picture.texture = texture
	picture.size = Vector2(diameter, diameter)
	picture.pivot_offset = picture.size / 2.0
	picture.rotation_degrees = degrees
	picture.position = Vector2(anchor.x * 360.0, anchor.y * 600.0)
	add_child(picture)
	return picture


func _add_swords(anchor: Vector2) -> void:
	var badge: PanelContainer = PanelContainer.new()
	badge.theme_type_variation = &"CardChallenge"
	badge.size = Vector2(68, 68)
	badge.position = Vector2(anchor.x * 360.0, anchor.y * 600.0)
	var icon: UiIcon = UiIcon.new()
	icon.texture = preload("res://game/ui/icons/swords.svg")
	icon.tone = UiIcon.Tone.GOLD
	icon.custom_minimum_size = Vector2(32, 32)
	badge.add_child(icon)
	add_child(badge)
