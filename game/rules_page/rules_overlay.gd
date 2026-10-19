class_name RulesOverlay
extends Control
## The rules over a game: a panel on the right, the whole screen on phones.
## The game and its timer keep running behind it. The close button, Escape or
## a tap outside the panel closes it.

const PANEL_WIDTH: float = 720.0
## The content's margins inside the scroll, left and right.
const CONTENT_MARGINS: float = 24.0

var _phone: bool = false

@onready var _veil: Control = %Veil
@onready var _panel: PanelContainer = %Panel
@onready var _close_button: Button = %CloseButton
@onready var _scroll: ScrollContainer = %Scroll
@onready var _content: RulesContent = %Content


func _ready() -> void:
	_close_button.pressed.connect(close)
	_veil.gui_input.connect(_on_veil_input)
	_scroll.resized.connect(_fit_content)
	_content.show_practice(false)
	_apply_size()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func use_preferences(preferences: PlayerPreferences) -> void:
	preferences.changed.connect(_show_preferences.bind(preferences))
	_show_preferences(preferences)


func set_phone(phone: bool) -> void:
	_phone = phone
	_apply_size()


func open() -> void:
	_scroll.scroll_vertical = 0
	show()
	_close_button.grab_focus()


func close() -> void:
	hide()


func content() -> RulesContent:
	return _content


func _show_preferences(preferences: PlayerPreferences) -> void:
	_content.set_adapted(preferences.adapted_colours)
	_content.set_reduced_motion(preferences.reduced_motion)


func _apply_size() -> void:
	_panel.anchor_left = 0.0 if _phone else 1.0
	_panel.offset_left = 0.0 if _phone else -PANEL_WIDTH


func _fit_content() -> void:
	_content.fit_width(_scroll.size.x - CONTENT_MARGINS)


func _on_veil_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			close()
