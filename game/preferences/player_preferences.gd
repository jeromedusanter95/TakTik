class_name PlayerPreferences
extends RefCounted
## The player's choices: language, nickname, Bot Difficulty, reduced motion,
## adapted colours and sound. Each change is saved at once and reported.

signal changed

const LANGUAGE: String = "language"
const NICKNAME: String = "nickname"
const DIFFICULTY: String = "difficulty"
const REDUCED_MOTION: String = "reduced_motion"
const ADAPTED_COLOURS: String = "adapted_colours"
const SOUND: String = "sound"
const _YES: String = "yes"
const _NO: String = "no"

var language: String:
	get:
		return _language
var nickname: String:
	get:
		return _nickname
## The index of the chosen Difficulty in the menu's list.
var difficulty: int:
	get:
		return _difficulty
var reduced_motion: bool:
	get:
		return _reduced_motion
var adapted_colours: bool:
	get:
		return _adapted_colours
var sound_on: bool:
	get:
		return _sound_on

var _store: PreferenceStore
var _language: String = Languages.ENGLISH
var _nickname: String = ""
var _difficulty: int = 1
var _reduced_motion: bool = false
var _adapted_colours: bool = false
var _sound_on: bool = true


## Reads what [param store] kept. [param device_language] and
## [param device_prefers_reduced_motion] fill the choices never made.
func _init(
		store: PreferenceStore, device_language: String, device_prefers_reduced_motion: bool
) -> void:
	_store = store
	_language = Languages.initial(store.load_value(LANGUAGE), device_language)
	_nickname = Nickname.cleaned(store.load_value(NICKNAME))
	var saved_difficulty: String = store.load_value(DIFFICULTY)
	if saved_difficulty.is_valid_int():
		_difficulty = maxi(0, saved_difficulty.to_int())
	_reduced_motion = _flag(store.load_value(REDUCED_MOTION), device_prefers_reduced_motion)
	_adapted_colours = _flag(store.load_value(ADAPTED_COLOURS), false)
	_sound_on = _flag(store.load_value(SOUND), true)


func set_language(code: String) -> void:
	if not Languages.is_supported(code) or code == _language:
		return
	_language = code
	_store.save_value(LANGUAGE, code)
	changed.emit()


## Keeps [param name] once cleaned; false, and nothing kept, when it is not a
## valid nickname.
func set_nickname(name: String) -> bool:
	var cleaned: String = Nickname.cleaned(name)
	if cleaned.is_empty():
		return false
	if cleaned != _nickname:
		_nickname = cleaned
		_store.save_value(NICKNAME, cleaned)
		changed.emit()
	return true


func set_difficulty(index: int) -> void:
	if index == _difficulty or index < 0:
		return
	_difficulty = index
	_store.save_value(DIFFICULTY, str(index))
	changed.emit()


func set_reduced_motion(enabled: bool) -> void:
	if enabled == _reduced_motion:
		return
	_reduced_motion = enabled
	_store.save_value(REDUCED_MOTION, _YES if enabled else _NO)
	changed.emit()


func set_adapted_colours(enabled: bool) -> void:
	if enabled == _adapted_colours:
		return
	_adapted_colours = enabled
	_store.save_value(ADAPTED_COLOURS, _YES if enabled else _NO)
	changed.emit()


func set_sound_on(enabled: bool) -> void:
	if enabled == _sound_on:
		return
	_sound_on = enabled
	_store.save_value(SOUND, _YES if enabled else _NO)
	changed.emit()


static func _flag(saved: String, fallback: bool) -> bool:
	if saved == _YES:
		return true
	if saved == _NO:
		return false
	return fallback
