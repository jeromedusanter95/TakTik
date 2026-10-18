class_name CaptureFlight
extends Control
## Flies a Piece that lost a Fight, grey, along an arc from the Board to its
## owner's losses tray.

const FLIGHT_TIME: float = 0.45
const ARC_HEIGHT: float = 70.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Flies [param texture] from [param from] to [param to], both global
## rectangles, then calls [param landed].
func fly(texture: Texture2D, from: Rect2, to: Rect2, landed: Callable) -> void:
	var picture: PiecePicture = PiecePicture.new()
	picture.texture = texture
	picture.set_grey(1.0)
	add_child(picture)
	var to_local: Transform2D = get_global_transform().affine_inverse()
	var start: Rect2 = Rect2(to_local * from.position, from.size)
	var end: Rect2 = Rect2(to_local * to.position, to.size)
	picture.position = start.position
	picture.size = start.size
	var tween: Tween = create_tween()
	tween.tween_method(
		func(progress: float) -> void:
			picture.size = start.size.lerp(end.size, progress)
			picture.position = start.position.lerp(end.position, progress) + Vector2(0.0, -ARC_HEIGHT * sin(PI * progress)),
		0.0, 1.0, FLIGHT_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(picture.queue_free)
	tween.tween_callback(landed)
