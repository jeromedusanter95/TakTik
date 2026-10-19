class_name RulesScreen
extends Control
## The rules page reached from the home screen: a top bar with Home and a
## practice game against the Bot, then the rules, centred and scrolling.

signal home_pressed
signal practice_pressed

const CONTENT_MAX_WIDTH: float = 1120.0
const PADDING_TOP: int = 48
const PADDING_SIDE: int = 24
const PADDING_BOTTOM: int = 80

var _preferences: PlayerPreferences = null
var _layout: ScreenLayout.Id = ScreenLayout.Id.WIDE

@onready var _top_bar: PanelContainer = %TopBar
@onready var _home_button: Button = %HomeButton
@onready var _practice_button: Button = %PracticeButton
@onready var _scroll: ScrollContainer = %Scroll
@onready var _margin: MarginContainer = %Margin
@onready var _content: RulesContent = %Content


func _ready() -> void:
	_home_button.pressed.connect(_on_home_pressed)
	_practice_button.pressed.connect(_on_practice_pressed)
	_content.practice_pressed.connect(_on_practice_pressed)
	_scroll.resized.connect(_centre_content)
	_apply_layout()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_home_pressed()


func use_preferences(preferences: PlayerPreferences) -> void:
	_preferences = preferences
	_preferences.changed.connect(_show_preferences)
	_show_preferences()


func set_layout(layout: ScreenLayout.Id) -> void:
	_layout = layout
	_apply_layout()


## The page is on screen again, from the top.
func open() -> void:
	_scroll.scroll_vertical = 0
	_home_button.grab_focus()


func content() -> RulesContent:
	return _content


func _show_preferences() -> void:
	_content.set_adapted(_preferences.adapted_colours)
	_content.set_reduced_motion(_preferences.reduced_motion)


## Phones keep the top bar's buttons as icons only.
func _apply_layout() -> void:
	var phone: bool = _layout == ScreenLayout.Id.PHONE
	_top_bar.custom_minimum_size.y = UiTokens.TOPBAR_PHONE if phone else UiTokens.TOPBAR_DESKTOP
	_home_button.text = "" if phone else "RULES_HOME"
	_practice_button.text = "" if phone else "RULES_PRACTICE"
	_centre_content()


## Keeps the rules at most CONTENT_MAX_WIDTH wide, in the middle.
func _centre_content() -> void:
	var side: float = maxf(_padding_side(), (_scroll.size.x - CONTENT_MAX_WIDTH) / 2.0)
	_margin.add_theme_constant_override("margin_left", roundi(side))
	_margin.add_theme_constant_override("margin_right", roundi(side))
	_margin.add_theme_constant_override("margin_top", PADDING_TOP)
	_margin.add_theme_constant_override("margin_bottom", PADDING_BOTTOM)
	_content.fit_width(_scroll.size.x - 2.0 * roundi(side))


func _padding_side() -> float:
	return UiTokens.SPACE_L if _layout == ScreenLayout.Id.PHONE else PADDING_SIDE


func _on_home_pressed() -> void:
	home_pressed.emit()


func _on_practice_pressed() -> void:
	practice_pressed.emit()
