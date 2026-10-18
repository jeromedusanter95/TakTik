class_name SheetHandle
extends Control
## The 44 by 5 grip at the top of a bottom sheet, which can be dragged down.


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var grip: Rect2 = Rect2(Vector2((size.x - 44.0) / 2.0, (size.y - 5.0) / 2.0), Vector2(44.0, 5.0))
	draw_style_box(UiStyles.box(UiTokens.BORDER_3, UiTokens.RADIUS_PILL), grip)
