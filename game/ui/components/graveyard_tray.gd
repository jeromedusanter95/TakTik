class_name GraveyardTray
extends HFlowContainer
## The Pieces one side lost, small and grey, or "None" while it lost none.

const TOKEN_SIZE: Vector2 = Vector2(34, 34)


func _init() -> void:
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param types], the Graveyard of [param side].
func show_graveyard(types: Array[PieceType.Id], side: Side.Id, adapted: bool = false) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if types.is_empty():
		var none: Label = Label.new()
		none.theme_type_variation = &"CaptionFaint"
		none.text = "GRAVEYARD_NONE"
		add_child(none)
		return
	for type: PieceType.Id in types:
		var picture: PiecePicture = PiecePicture.new()
		picture.custom_minimum_size = TOKEN_SIZE
		picture.show_piece(type, side, true, adapted)
		add_child(picture)
