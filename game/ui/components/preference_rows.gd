class_name PreferenceRows
extends VBoxContainer
## The choices a player can change anywhere: language, reduced motion and
## adapted colours. Each row edits PlayerPreferences directly.

const LANGUAGE_CODES: Array[String] = ["fr", "en"]

var _preferences: PlayerPreferences = null

@onready var _language: SegmentedControl = %Language
@onready var _motion: SegmentedControl = %Motion
@onready var _colours: SegmentedControl = %Colours


func _ready() -> void:
	_language.show_options(["FR", "EN"], 0)
	_motion.show_options(["PREFERENCE_NO", "PREFERENCE_YES"], 0)
	_colours.show_options(["PREFERENCE_NO", "PREFERENCE_YES"], 0)
	_language.option_chosen.connect(_on_language_chosen)
	_motion.option_chosen.connect(_on_motion_chosen)
	_colours.option_chosen.connect(_on_colours_chosen)


func use_preferences(preferences: PlayerPreferences) -> void:
	_preferences = preferences
	_preferences.changed.connect(_show_preferences)
	_show_preferences()


func _show_preferences() -> void:
	_language.select(LANGUAGE_CODES.find(_preferences.language))
	_motion.select(1 if _preferences.reduced_motion else 0)
	_colours.select(1 if _preferences.adapted_colours else 0)


func _on_language_chosen(index: int) -> void:
	_preferences.set_language(LANGUAGE_CODES[index])


func _on_motion_chosen(index: int) -> void:
	_preferences.set_reduced_motion(index == 1)


func _on_colours_chosen(index: int) -> void:
	_preferences.set_adapted_colours(index == 1)
