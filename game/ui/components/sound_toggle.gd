class_name SoundToggle
extends Button
## The speaker button: turns the game's sound on and off, for the whole game.

const SoundOnIcon: Texture2D = preload("res://game/ui/icons/volume_2.svg")
const SoundOffIcon: Texture2D = preload("res://game/ui/icons/volume_x.svg")

var _preferences: PlayerPreferences = null


func _init() -> void:
	theme_type_variation = &"IconButton"
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expand_icon = true
	custom_minimum_size = Vector2(46, 46)
	icon = SoundOnIcon
	tooltip_text = "SOUND_TOGGLE"
	add_child(PressScaleFeedback.new())


func _ready() -> void:
	pressed.connect(_on_pressed)


func use_preferences(preferences: PlayerPreferences) -> void:
	_preferences = preferences
	_preferences.changed.connect(_show)
	_show()


func _show() -> void:
	icon = SoundOnIcon if _preferences.sound_on else SoundOffIcon


func _on_pressed() -> void:
	if _preferences != null:
		_preferences.set_sound_on(not _preferences.sound_on)
